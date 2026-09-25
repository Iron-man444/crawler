require_relative "test_helper"

class DiscoveryTest < Minitest::Test
  def test_generic_link_ranking_uses_anchor_text_and_drops_navigation
    html = <<~HTML
      <nav><a href="/about">Hakkımızda</a><a href="/contact">İletişim</a></nav>
      <a href="/other">Diğer içerik</a>
      <a href="/p/123">2026 Sanayi Buluşması</a>
      <a href="/duyurular">Duyurular</a>
      <a href="/p/123?utm_source=test">Aynı etkinlik</a>
      <a href="/poster.jpg">Fuar afişi</a>
    HTML
    result = Radar::Extractor.call(html, "https://example.org/", "text/html")
    assert_equal ["https://example.org/p/123", "https://example.org/duyurular", "https://example.org/other"], result["links"]
  end

  def test_bridge_access_requires_explicit_container_mode
    prior = ENV.delete("RADAR_CONTAINER_NETWORK")
    assert_raises(RuntimeError) { Radar::BotClient.new("http://radar:8787", "fake") }
    ENV["RADAR_CONTAINER_NETWORK"] = "1"
    assert_instance_of Radar::BotClient, Radar::BotClient.new("http://radar:8787", "fake")
    assert_equal "0.0.0.0", config["listen"]
    assert_raises(RuntimeError) { Radar::BotClient.new("http://external.test:8787", "fake") }
  ensure
    prior ? ENV["RADAR_CONTAINER_NETWORK"] = prior : ENV.delete("RADAR_CONTAINER_NETWORK")
  end
end
