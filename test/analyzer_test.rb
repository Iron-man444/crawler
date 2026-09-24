require_relative "test_helper"

class AnalyzerTest < Minitest::Test
  def test_both_provider_contracts
    %w[gemini mistral].each do |provider|
      settings = config["llm"].merge("provider" => provider, "model" => "test-model", "api_key_env" => "RADAR_TEST_KEY")
      ENV["RADAR_TEST_KEY"] = "fake-not-a-secret"
      expected = item.slice(*Radar::Analyzer::FIELDS)
      fake = FakeHTTP.new do |_, _, args|
        body = JSON.parse(args[:body])
        if provider == "gemini"
          assert_equal "application/json", body.dig("generationConfig", "responseMimeType")
          assert body.dig("generationConfig", "responseJsonSchema", "properties", "items")
          envelope = { "candidates" => [{ "finishReason" => "STOP", "content" => { "parts" => [{ "text" => JSON.generate("items" => [expected]) }] } }] }
        else
          assert_equal "json_schema", body.dig("response_format", "type")
          envelope = { "choices" => [{ "finish_reason" => "stop", "message" => { "content" => JSON.generate("items" => [expected]) } }] }
        end
        response(200, JSON.generate(envelope))
      end
      analyzer = Radar::Analyzer.new(settings, http: fake)
      assert_equal expected["title"], analyzer.analyze(expected["evidence"], profile).first["title"]
    ensure
      ENV.delete("RADAR_TEST_KEY")
    end
  end

  def test_unverified_evidence_and_wrong_schema_are_not_irrelevant
    a = Radar::Analyzer.new(config["llm"], http: nil)
    e = assert_raises(Radar::WorkError) { a.validate({ "items" => [item.slice(*Radar::Analyzer::FIELDS)] }, "Tamamen farklı kaynak") }
    assert_equal "llm_unverified_evidence", e.code
    assert_raises(Radar::WorkError) { a.validate({ "items" => [{}] }, "") }
    assert_raises(Radar::WorkError) { a.validate({ "items" => [item.slice(*Radar::Analyzer::FIELDS).merge("date" => "2030-02-31")] }, item["evidence"]) }
  end

  def test_chunk_overlap_and_overflow
    a = Radar::Analyzer.new(config["llm"].merge("chunk_chars" => 1000, "max_chunks" => 3), http: nil)
    parts = a.chunks("a" * 1700)
    assert_equal [1000, 1000], parts.map(&:length)
    assert_raises(Radar::WorkError) { a.chunks("a" * 5000) }
  end

  def test_provider_truncated_response_is_retried
    ENV["RADAR_TEST_KEY"] = "fake"
    http = FakeHTTP.new { response(200, JSON.generate("candidates" => [{ "finishReason" => "MAX_TOKENS" }])) }
    a = Radar::Analyzer.new(config["llm"].merge("model" => "test", "api_key_env" => "RADAR_TEST_KEY"), http: http)
    assert_equal "llm_incomplete_response", assert_raises(Radar::WorkError) { a.analyze(item["evidence"], profile) }.code
  ensure
    ENV.delete("RADAR_TEST_KEY")
  end
end
