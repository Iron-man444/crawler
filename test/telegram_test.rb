require_relative "test_helper"

class TelegramTest < Minitest::Test
  class Client
    attr_reader :calls
    def initialize(job, fail_ack: false)
      @job, @calls, @fail_ack = job, [], fail_ack
    end
    def call(path, body = {})
      @calls << [path, body]
      return @job if path.end_with?("/claim")
      raise Radar::WorkError.new("bot_api_unavailable") if @fail_ack && path.end_with?("/ack")
      { "ok" => true }
    end
  end
  def job
    { "delivery_id" => "abc", "claim_token" => "token", "target_ref" => "main", "payload" => { "kind" => "new", "item" => item, "url" => "https://example.org/event", "checked_at" => Time.now.utc.iso8601 } }
  end
  def bot(client, http, targets = { "main" => "123" })
    Radar::Telegram.new(client: client, http: http, token: "fake", targets: targets)
  end
  def test_success_and_unauthorized_target
    client = Client.new(job)
    http = FakeHTTP.new { response(200, '{"ok":true,"result":{"message_id":42}}') }
    assert bot(client, http).once
    assert_equal "42", client.calls.last[1]["message_id"]
    client = Client.new(job)
    bot(client, http, {}).once
    assert_equal "permanent", client.calls.last[1]["type"]
    assert_equal 1, http.calls.size
  end
  def test_timeout_does_not_retry_send
    client = Client.new(job)
    http = FakeHTTP.new { raise Radar::WorkError.new("network_error") }
    bot(client, http).once
    assert_equal "unknown_delivery", client.calls.last[1]["type"]
    assert_equal 1, http.calls.size
  end
  def test_429_respects_retry_after
    client = Client.new(job)
    http = FakeHTTP.new { response(429, '{"ok":false,"error_code":429,"parameters":{"retry_after":90}}') }
    bot(client, http).once
    assert_equal "transient", client.calls.last[1]["type"]
    assert_equal 90, client.calls.last[1]["retry_after"]
  end
  def test_ack_failure_never_resends
    client = Client.new(job, fail_ack: true)
    http = FakeHTTP.new { response(200, '{"ok":true,"result":{"message_id":42}}') }
    b = bot(client, http)
    b.stub(:sleep, nil) { assert_raises(Radar::WorkError) { b.once } }
    assert_equal 1, http.calls.size
    assert_equal 3, client.calls.count { |path, _| path.end_with?("/ack") }
  end
  def test_plain_text_utf16_limit
    payload = job["payload"]
    payload["item"]["summary"] = "🧑" * 5000
    text = Radar::Telegram.text(payload)
    assert_operator text.encode("UTF-16LE").bytesize / 2, :<=, 4000
    assert_includes text, payload["url"]
  end
end
