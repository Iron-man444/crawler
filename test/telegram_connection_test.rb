require "minitest/autorun"
require "json"
require_relative "../lib/radar/http"
require_relative "../lib/radar/telegram"

class TelegramConnectionTest < Minitest::Test
  class Transport
    attr_reader :calls
    def initialize(response = nil)
      @response, @calls = response, []
    end
    def request(*args, **kwargs)
      @calls << [args, kwargs]
      raise Radar::WorkError.new("network_error") unless @response
      @response
    end
  end
  def test_sends_without_client_database_or_llm
    http = Transport.new(Radar::HTTP::Response.new(200, {}, '{"ok":true,"result":{"message_id":42}}', ""))
    bot = Radar::Telegram.new(client: nil, http: http, token: "fake", targets: {"main" => "123"})
    assert_equal 42, bot.test_message
    assert_equal "123", JSON.parse(http.calls.first.last[:body])["chat_id"]
    assert_equal 1, http.calls.size
  end
  def test_uncertain_send_is_not_retried
    http = Transport.new
    bot = Radar::Telegram.new(client: nil, http: http, token: "fake", targets: {"main" => "123"})
    error = assert_raises(Radar::WorkError) { bot.test_message }
    assert_equal "telegram_test_delivery_unknown", error.code
    assert_equal 1, http.calls.size
  end
  def test_missing_target_never_sends
    http = Transport.new
    bot = Radar::Telegram.new(client: nil, http: http, token: "fake", targets: {})
    assert_raises(Radar::WorkError) { bot.test_message }
    assert_empty http.calls
  end
end
