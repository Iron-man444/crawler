require "bundler/setup"
require "minitest/autorun"
require "minitest/mock"
require "stringio"
require_relative "../lib/radar"
require_relative "../lib/radar/telegram"

module Fixtures
  def config
    Radar::Config.new(File.expand_path("../config/settings.example.json", __dir__))
  end
  def profile
    config.data["profiles"].first.merge("enabled" => true, "allowed_domains" => ["example.org"], "seed_urls" => ["https://example.org/events"])
  end
  def item
    { "title" => "Yazılım Buluşması", "type" => "event", "summary" => "Yazılım firmaları bir araya geliyor.",
      "relevance" => "relevant", "reason" => "İş ortaklığı görüşmeleri var.",
      "evidence" => "Yazılım firmaları 2030 yılında İstanbul'da buluşacak.", "date" => "2030-10-15",
      "location" => "İstanbul", "inferred_tags" => ["yazılım"], "source_tags" => [], "user_tags" => [] }
  end
  def response(status, body, headers = {}, url = "https://example.org/events")
    Radar::HTTP::Response.new(status, headers, body, url)
  end
end

class FakeHTTP
  attr_reader :calls
  def initialize(&block)
    @block, @calls = block, []
  end
  def request(method, url, **args)
    @calls << [method, url, args]
    args[:before_request]&.call(URI(url).host)
    @block.call(method, url, args)
  end
end

class Minitest::Test
  include Fixtures
end
