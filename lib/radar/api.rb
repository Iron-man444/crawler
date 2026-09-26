require "webrick"
require "openssl"

module Radar
  class API
    def initialize(config, store, token: ENV.fetch("RADAR_API_TOKEN"))
      @store, @token, @profiles = store, token, config.profiles
      @server = WEBrick::HTTPServer.new(BindAddress: config["listen"], Port: config["port"],
        AccessLog: [], Logger: WEBrick::Log.new(File::NULL), MaxClients: 8, RequestTimeout: 10)
      @server.mount_proc("/") { |req, res| handle(req, res) }
    end
    def start = @server.start
    def shutdown = @server.shutdown

    def handle(req, res)
      res["Content-Type"] = "application/json; charset=utf-8"
      supplied = req["authorization"].to_s.delete_prefix("Bearer ")
      unless supplied.bytesize == @token.bytesize && OpenSSL.fixed_length_secure_compare(supplied, @token)
        res.status = 401
        res.body = '{"error":"unauthorized"}'
        return
      end
      if req.request_method == "GET" && req.path == "/api/v1/status"
        res.body = JSON.generate(@store.status)
      elsif req.request_method == "POST" && req.path == "/api/v1/notification-jobs/claim"
        job = @store.claim_delivery(profiles: @profiles)
        res.status = job ? 200 : 204
        res.body = job ? JSON.generate(job) : ""
      elsif req.request_method == "POST" && (match = req.path.match(%r{\A/api/v1/notification-jobs/([0-9a-f-]{36})/(ack|fail|renew)\z}))
        raise ArgumentError if req.body.to_s.bytesize > 8192
        input = JSON.parse(req.body.to_s)
        raise ArgumentError unless input.is_a?(Hash) && input["claim_token"].is_a?(String)
        ok = @store.delivery_action(match[1], match[2], input)
        res.status = ok ? 200 : 409
        res.body = JSON.generate(ok ? { "ok" => true } : { "error" => "invalid_or_expired_claim" })
      else
        res.status = 404
        res.body = '{"error":"not_found"}'
      end
    rescue JSON::ParserError, ArgumentError, TypeError
      res.status = 400
      res.body = '{"error":"invalid_request"}'
    rescue StandardError
      res.status = 503
      res.body = '{"error":"service_unavailable"}'
    end
  end
end
