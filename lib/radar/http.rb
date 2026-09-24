require "net/http"
require "uri"
require "ipaddr"
require "resolv"
require "timeout"

module Radar
  class WorkError < StandardError
    attr_reader :code, :delay, :permanent
    def initialize(code, delay: 60, permanent: false)
      @code, @delay, @permanent = code, delay, permanent
      super(code)
    end
  end

  module URL
    BLOCKS = %w[0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 192.0.0.0/24 192.0.2.0/24 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4 ::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8 2001:db8::/32].map { |v| IPAddr.new(v) }.freeze
    def self.public_ip?(str)
      ip = IPAddr.new(str)
      ip = ip.native if ip.ipv4_mapped?
      # Only global-unicast IPv6. Deny transition mechanisms with embedded IPv4.
      return false if ip.ipv6? && (!IPAddr.new("2000::/3").include?(ip) || IPAddr.new("2002::/16").include?(ip) || IPAddr.new("2001::/32").include?(ip))
      !BLOCKS.any? { |net| net.include?(ip) }
    rescue IPAddr::InvalidAddressError
      false
    end

    def self.canonical(raw, base = nil)
      raise WorkError.new("url_too_long", permanent: true) if raw.bytesize > 2000
      u = base ? URI.join(base, raw) : URI.parse(raw)
      raise WorkError.new("unsafe_url", permanent: true) unless %w[http https].include?(u.scheme) && u.host && !u.userinfo && [80, 443].include?(u.port)
      u.host = u.host.downcase
      u.fragment = nil
      u.path = "/" if u.path.empty?
      if u.query
        pairs = URI.decode_www_form(u.query).reject { |k, _| k.match?(/\A(?:utm_.*|fbclid|gclid)\z/i) }
        u.query = pairs.empty? ? nil : URI.encode_www_form(pairs.sort)
      end
      u.to_s
    rescue URI::Error, ArgumentError
      raise WorkError.new("invalid_url", permanent: true)
    end

    def self.allowed?(url, domains)
      host = URI.parse(canonical(url)).host
      domains.any? { |d| host == d || host.end_with?(".#{d}") }
    rescue WorkError
      false
    end
  end

  class HTTP
    Response = Data.define(:status, :headers, :body, :url)
    def initialize(user_agent: "FirsatRadari/0.1", resolver: Resolv)
      @user_agent, @resolver = user_agent, resolver
    end

    def request(method, url, headers: {}, body: nil, domains: nil, limit: 2_000_000, before_request: nil, follow_redirects: true)
      current = URL.canonical(url)
      5.times do
        raise WorkError.new("domain_not_allowed", permanent: true) if domains && !URL.allowed?(current, domains)
        uri = URI(current)
        ips = @resolver.getaddresses(uri.hostname)
        raise WorkError.new("unsafe_address", permanent: true) if ips.empty? || ips.any? { |ip| !URL.public_ip?(ip) }
        before_request&.call(uri.host)
        http = Net::HTTP.new(uri.hostname, uri.port, nil)
        http.ipaddr = ips.first # Pin validated DNS result, keeping original TLS hostname verification.
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 10
        http.read_timeout = 30
        http.write_timeout = 15
        http.max_retries = 0
        req = (method == :post ? Net::HTTP::Post : Net::HTTP::Get).new(uri.request_uri)
        req["User-Agent"] = @user_agent
        req["Accept-Encoding"] = "identity"
        headers.each { |k, v| req[k] = v }
        req.body = body if body
        response = nil
        Timeout.timeout(60) do
          http.start do |client|
            client.request(req) do |r|
              content = +""
              r.read_body do |part|
                content << part
                raise WorkError.new("response_too_large", permanent: true) if content.bytesize > limit
              end
              response = Response.new(r.code.to_i, r.to_hash.transform_values(&:first), content, current)
            end
          end
        end
        unless follow_redirects && [301, 302, 303, 307, 308].include?(response.status)
          return response
        end
        # Provider redirects must never forward secrets to a different endpoint.
        raise WorkError.new("provider_redirect", permanent: true) if method == :post || !headers.empty? && domains.nil?
        next_url = URL.canonical(response.headers.fetch("location", ""), current)
        raise WorkError.new("https_downgrade", permanent: true) if uri.scheme == "https" && URI(next_url).scheme != "https"
        current = next_url
      end
      raise WorkError.new("redirect_limit", permanent: true)
    rescue WorkError
      raise
    rescue Timeout::Error, IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse
      raise WorkError.new("network_error")
    end

    def self.check!(response)
      return response if (200..299).cover?(response.status)
      retry_after = response.headers["retry-after"]
      delay = if retry_after&.match?(/\A\d+\z/)
                retry_after.to_i
              elsif retry_after
                [(Time.httpdate(retry_after) - Time.now).ceil, 1].max rescue 60
              else
                60
              end
      raise WorkError.new("http_#{response.status}", delay: [delay, 1].max, permanent: [400, 401, 402, 403, 404, 410, 422].include?(response.status))
    end
  end
end
