require_relative "test_helper"

class CoreTest < Minitest::Test
  def test_turkish_word_boundaries
    assert Radar::Filter.contains?("İŞ ORTAKLIĞI ve YAZILIM", "iş ortaklığı")
    assert Radar::Filter.contains?("AI, yazılım", "ai")
    refute Radar::Filter.contains?("mail kampanyası", "ai")
  end

  def test_filter_dimensions_and_exclusions
    p = profile.merge("include_words" => ["yazılım", "ortaklık"], "match_mode" => "all")
    assert_equal "word_mismatch", Radar::Filter.decision(item, p)
    assert_equal "matched", Radar::Filter.decision(item, p.merge("match_mode" => "any"))
    assert_equal "excluded_type", Radar::Filter.decision(item.merge("type" => "education"), profile)
    assert_equal "excluded_word", Radar::Filter.decision(item.merge("summary" => "Sertifika fırsatı"), profile)
    assert_equal "past_event", Radar::Filter.decision(item.merge("date" => "2020-01-01"), profile)
    assert_equal "location_mismatch", Radar::Filter.decision(item.merge("location" => nil), profile.merge("locations" => ["Ankara"]))
  end

  def test_private_and_mapped_ips_rejected
    %w[127.0.0.1 169.254.169.254 10.0.0.1 100.64.1.1 ::1 ::ffff:127.0.0.1 2002:7f00:1::1].each { |ip| refute Radar::URL.public_ip?(ip), ip }
    assert Radar::URL.public_ip?("8.8.8.8")
    refute Radar::URL.allowed?("https://example.org.evil.test/a", ["example.org"])
    assert Radar::URL.allowed?("https://events.example.org/a", ["example.org"])
    assert_raises(Radar::WorkError) { Radar::URL.canonical("http://user:password@example.org") }
  end

  def test_dns_rebinding_defense_checks_all_addresses_before_dialing
    resolver = Object.new
    def resolver.getaddresses(*) = ["8.8.8.8", "127.0.0.1"]
    error = assert_raises(Radar::WorkError) { Radar::HTTP.new(resolver: resolver).request(:get, "https://example.org") }
    assert_equal "unsafe_address", error.code
  end

  def test_url_canonicalization_preserves_identity
    assert_equal "https://example.org/a?id=42", Radar::URL.canonical("https://EXAMPLE.org/a?utm_source=x&id=42#top")
  end

  def test_extractor_removes_navigation_and_discovers_links
    html = '<title>Etkinlikler</title><nav>İndirim</nav><main><p>Yazılım #AI buluşması</p><a href="/detail?id=2&utm_source=x">Detay</a></main><footer>Kupon</footer>'
    doc = Radar::Extractor.call(html, "https://example.org/events", "text/html")
    refute_includes doc["text"], "İndirim"
    refute_includes doc["text"], "Kupon"
    assert_includes doc["text"], "Yazılım"
    assert_equal ["#AI"], doc["source_tags"]
    assert_equal ["https://example.org/detail?id=2"], doc["links"]
  end

  def test_sitemap_and_challenge
    doc = Radar::Extractor.call('<urlset><url><loc>https://example.org/a</loc></url></urlset>', "https://example.org/sitemap.xml", "application/xml")
    assert_equal ["https://example.org/a"], doc["links"]
    assert_raises(Radar::WorkError) { Radar::Extractor.call('<title>Just a moment...</title>', "https://example.org", "text/html") }
  end

  def test_binary_http_body_preserves_turkish_characters
    body = '<meta charset="utf-8"><main>İstanbul yazılım iş ortaklığı</main>'.b
    doc = Radar::Extractor.call(body, "https://example.org", "text/html")
    assert_includes doc["text"], "İstanbul yazılım iş ortaklığı"
    latin = '<main>Français</main>'.encode("ISO-8859-1").b
    doc = Radar::Extractor.call(latin, "https://example.org", "text/html; charset=ISO-8859-1")
    assert_includes doc["text"], "Français"
  end

  def test_robots_specific_group_and_longest_allow
    rules = Radar::Robots.new("User-agent: *\nDisallow: /\nUser-agent: FirsatRadari\nDisallow: /private\nAllow: /private/public\nDisallow: /*?secret=*$\n")
    assert rules.allowed?("https://example.org/events")
    refute rules.allowed?("https://example.org/private")
    assert rules.allowed?("https://example.org/private/public")
    refute rules.allowed?("https://example.org/x?secret=abc")
  end

  def test_rate_limit_retry_after_and_forbidden
    e = assert_raises(Radar::WorkError) { Radar::HTTP.check!(response(429, "", { "retry-after" => "3600" })) }
    assert_equal 3600, e.delay
    refute e.permanent
    e = assert_raises(Radar::WorkError) { Radar::HTTP.check!(response(403, "")) }
    assert e.permanent
  end

  def test_configuration_rejects_private_seed_and_duplicate_profiles
    assert_equal 0, config.profiles.length
    c = config
    c.data["profiles"] << c.data["profiles"].first.dup
    assert_raises(RuntimeError) { c.validate! }
  end
end
