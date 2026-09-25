require "net/http"

module Radar
  class BotClient
    def initialize(base, token)
      @base = URI(base)
      raise "RADAR_URL loopback HTTP olmalı" unless @base.scheme == "http" && %w[127.0.0.1 localhost ::1].include?(@base.hostname)
      @token = token
    end
    def call(path, payload = {})
      uri = URI.join(@base.to_s, path)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
      response = Net::HTTP.start(uri.hostname, uri.port, nil, open_timeout: 5, read_timeout: 15) { |h| h.request(request) }
      return nil if response.code == "204"
      raise WorkError.new("bot_api_#{response.code}") unless response.code == "200"
      JSON.parse(response.body)
    rescue JSON::ParserError, Timeout::Error, IOError, SystemCallError, SocketError
      raise WorkError.new("bot_api_unavailable")
    end
  end

  class Telegram
    def initialize(client:, http: HTTP.new, token:, targets:)
      @client, @http, @token, @targets = client, http, token, targets
      raise "Telegram token eksik" if token.empty?
      raise "TELEGRAM_TARGETS nesne olmalı" unless targets.is_a?(Hash) && targets.values.all? { |v| v.to_s.match?(/\A-?\d+\z/) }
    end

    def self.text(payload)
      item = payload.fetch("item")
      lines = [payload["kind"] == "updated" ? "GÜNCELLEME" : "YENİ BİLGİ", cut(item.fetch("title"), 250),
               cut(item.fetch("summary"), 450), "Neden ilgili: #{cut(item['reason'], 200)}"]
      lines << "Tarih: #{item['date']}" if item["date"]
      lines << "Konum: #{cut(item['location'], 120)}" if item["location"]
      lines << "Etiketler: #{cut(item.fetch('inferred_tags', []).join(', '), 200)}"
      lines << "Kaynak: #{payload.fetch('url')}"
      lines << "Kontrol: #{payload.fetch('checked_at')}"
      lines << "Kanıt: kaynak metnindeki alıntı doğrulandı"
      # Telegram counts UTF-16 code units. Keep room below its 4096-unit limit.
      cut(lines.join("\n\n"), 4000)
    end

    def self.cut(text, limit)
      out, units = +"", 0
      text.to_s.each_char do |char|
        size = char.ord > 0xffff ? 2 : 1
        break if units + size > limit
        out << char
        units += size
      end
      out
    end

    # Explicit connection test: no queue, database or LLM dependency; never retry a send.
    def test_message(target_ref = "main")
      chat = @targets[target_ref]
      raise WorkError.new("telegram_target_missing", permanent: true) unless chat
      begin
        response = @http.request(:post, "https://api.telegram.org/bot#{@token}/sendMessage",
          headers: { "Content-Type" => "application/json" },
          body: JSON.generate(chat_id: chat, text: "✅ Fırsat Radarı test mesajı. Telegram bağlantısı çalışıyor. Bu mesaj tarama ve Gemini analizinden bağımsızdır."))
        data = JSON.parse(response.body)
      rescue WorkError, JSON::ParserError
        raise WorkError.new("telegram_test_delivery_unknown", permanent: true)
      end
      unless response.status == 200 && data["ok"] == true && data.dig("result", "message_id")
        code = data["error_code"].is_a?(Integer) ? data["error_code"] : response.status
        raise WorkError.new("telegram_test_http_#{code}", permanent: true)
      end
      data["result"]["message_id"]
    end

    def once
      job = @client.call("/api/v1/notification-jobs/claim")
      return false unless job
      path = "/api/v1/notification-jobs/#{job.fetch('delivery_id')}"
      claim = { "claim_token" => job.fetch("claim_token") }
      chat = @targets[job["target_ref"]]
      unless chat
        @client.call("#{path}/fail", claim.merge("type" => "permanent"))
        return true
      end
      begin
        response = @http.request(:post, "https://api.telegram.org/bot#{@token}/sendMessage",
          headers: { "Content-Type" => "application/json" },
          body: JSON.generate(chat_id: chat, text: self.class.text(job.fetch("payload")), link_preview_options: { is_disabled: true }))
        data = JSON.parse(response.body)
      rescue WorkError, JSON::ParserError
        # A network failure after send may mean the message arrived. Never blindly resend.
        @client.call("#{path}/fail", claim.merge("type" => "unknown_delivery"))
        return true
      end
      if response.status == 200 && data["ok"] == true && data.dig("result", "message_id")
        # Retry only ACK; never repeat sendMessage after an ACK failure.
        3.times do |attempt|
          begin
            @client.call("#{path}/ack", claim.merge("message_id" => data["result"]["message_id"].to_s))
            return true
          rescue WorkError
            raise if attempt == 2
            sleep 1
          end
        end
      else
        type = if response.status == 429 || data["error_code"] == 429
                 "transient"
               elsif [400, 401, 403, 404].include?(response.status) || [400, 401, 403, 404].include?(data["error_code"])
                 "permanent"
               else
                 "unknown_delivery"
               end
        @client.call("#{path}/fail", claim.merge("type" => type, "retry_after" => data.dig("parameters", "retry_after") || 60))
      end
      true
    end
  end
end
