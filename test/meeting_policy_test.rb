require_relative "test_helper"

class MeetingPolicyTest < Minitest::Test
  def meeting_profile
    profile.merge("meeting_only" => true, "allowed_types" => ["event"], "include_words" => [], "exclude_words" => [], "include_tags" => [], "exclude_tags" => [])
  end

  def test_actual_customs_notice_is_rejected_even_if_model_labels_it_relevant
    notice = item.merge("title" => "Gümrük Müşavirleri için Vekaleten Belge Talebi",
      "summary" => "Gümrük müşavirlerinin firma adına menşe ve dolaşım belgeleri alabilmesi için gerekli prosedür ve belgeler.",
      "evidence" => "Gümrük müşavirleri vekaleten menşe ve dolaşım belgesi alabilir.", "type" => "announcement", "date" => nil)
    assert_equal "not_meeting", Radar::Filter.decision(notice, meeting_profile)
    assert_equal "no_meeting_evidence", Radar::Filter.decision(notice.merge("type" => "event", "date" => "2030-10-15"), meeting_profile)
  end

  def test_trade_fair_and_professional_conference_are_allowed_but_missing_date_is_held
    event = item.merge("title" => "Mobilya Fuarı", "evidence" => "Mobilya Fuarı 15 Ekim 2030 tarihinde İstanbul'da düzenlenecek.")
    assert_equal "matched", Radar::Filter.decision(event, meeting_profile)
    assert_equal "missing_event_date", Radar::Filter.decision(event.merge("date" => nil), meeting_profile)
    assert_equal "past_event", Radar::Filter.decision(event.merge("date" => "2020-01-01"), meeting_profile)
    assert_equal "past_report", Radar::Filter.decision(event.merge("evidence" => "Mobilya Fuarı katılımcılarıyla gerçekleştirildi."), meeting_profile)
    conference = item.merge("title" => "Gümrük Müşavirleri Konferansı", "evidence" => "Gümrük müşavirleri konferansı 15 Ekim 2030 tarihinde düzenlenecek.")
    assert_equal "matched", Radar::Filter.decision(conference, meeting_profile)
  end

  def test_notice_only_page_makes_zero_llm_requests_even_if_long
    a = Radar::Analyzer.new(config["llm"], http: FakeHTTP.new { flunk "Administrative text must not reach LLM" }, budget: -> { flunk "No budget should be used" })
    assert_empty a.analyze("Gümrük müşavirleri için vekaleten belge talebi. " * 5000, meeting_profile)
  end

  def test_runtime_changes_preserve_signature_but_policy_and_model_changes_invalidate
    settings = config["llm"]
    a = Radar::Analyzer.new(settings, http: nil)
    b = Radar::Analyzer.new(settings.merge("max_calls_per_day" => 1000, "min_interval_seconds" => 10, "api_key_env" => "NEW_KEY"), http: nil)
    changed_source = meeting_profile.merge("id" => "other", "seed_urls" => ["https://another.test"], "max_pages" => 99, "interval_seconds" => 3600, "target_ref" => "group")
    assert_equal a.signature(meeting_profile), b.signature(changed_source)
    refute_equal a.signature(meeting_profile), a.signature(meeting_profile.merge("description" => "Different policy"))
    refute_equal a.signature(meeting_profile), Radar::Analyzer.new(settings.merge("model" => "other"), http: nil).signature(meeting_profile)
  end

  def test_only_candidate_chunks_and_neighbors_reach_provider
    ENV["RADAR_TEST_KEY"] = "fake"
    settings = config["llm"].merge("chunk_chars" => 1000, "max_chunks" => 12, "api_key_env" => "RADAR_TEST_KEY", "model" => "fake")
    text = ("İdari belge işlemleri. " * 350)
    text[3500, 0] = " Konferans 15 Ekim 2030 tarihinde yapılacak. "
    http = FakeHTTP.new { response(200, JSON.generate("candidates" => [{ "finishReason" => "STOP", "content" => { "parts" => [{ "text" => '{"items":[]}' }] } }])) }
    a = Radar::Analyzer.new(settings, http: http)
    assert_empty a.analyze(text, meeting_profile)
    assert_operator http.calls.size, :>, 0
    assert_operator http.calls.size, :<, a.chunks(text).size
  ensure
    ENV.delete("RADAR_TEST_KEY")
  end

  def test_identical_content_reuses_cache_between_profiles
    ENV["RADAR_TEST_KEY"] = "fake"
    settings = config["llm"].merge("api_key_env" => "RADAR_TEST_KEY", "model" => "fake")
    cache = Object.new
    entries = {}
    cache.define_singleton_method(:cached_analysis) { |key| entries[key] }
    cache.define_singleton_method(:cache_analysis) { |key, value| entries[key] = value }
    expected = item.slice(*Radar::Analyzer::FIELDS).merge("evidence" => "Yazılım Buluşması 15 Ekim 2030 tarihinde İstanbul'da düzenlenecek.")
    http = FakeHTTP.new { response(200, JSON.generate("candidates" => [{ "finishReason" => "STOP", "content" => { "parts" => [{ "text" => JSON.generate("items" => [expected]) }] } }])) }
    a = Radar::Analyzer.new(settings, http: http, cache: cache)
    first = a.analyze(expected["evidence"], meeting_profile)
    second = a.analyze(expected["evidence"], meeting_profile.merge("id" => "another"))
    assert_equal first, second
    assert_equal 1, http.calls.size
  ensure
    ENV.delete("RADAR_TEST_KEY")
  end
end
