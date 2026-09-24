module Radar
  module Filter
    def self.normalize(text)
      text.to_s.unicode_normalize(:nfkc).tr("İIı", "iii").downcase.scan(/[\p{L}\p{N}]+/).join(" ")
    end

    def self.contains?(text, term)
      needle = normalize(term)
      !needle.empty? && " #{normalize(text)} ".include?(" #{needle} ")
    end

    def self.match_dimension?(terms, text, mode)
      return true if terms.empty?
      mode == "all" ? terms.all? { |t| contains?(text, t) } : terms.any? { |t| contains?(text, t) }
    end

    def self.decision(item, profile, today: Date.today)
      return "uncertain" if item["relevance"] == "uncertain"
      return "irrelevant" unless item["relevance"] == "relevant"
      return "excluded_type" if profile["excluded_types"].include?(item["type"])
      return "type_mismatch" unless profile["allowed_types"].empty? || profile["allowed_types"].include?(item["type"])
      text = %w[title summary evidence location].map { |k| item[k] }.compact.join(" ")
      tags = (item["source_tags"] + item["inferred_tags"]).join(" ")
      return "excluded_word" if profile["exclude_words"].any? { |w| contains?(text, w) }
      return "excluded_tag" if profile["exclude_tags"].any? { |w| contains?(tags, w) }
      return "word_mismatch" unless match_dimension?(profile["include_words"], text, profile["match_mode"])
      return "tag_mismatch" unless match_dimension?(profile["include_tags"], tags, profile["match_mode"])
      return "location_mismatch" unless match_dimension?(profile["locations"], item["location"], "any")
      if profile["exclude_past_events"] && item["type"] == "event" && item["date"] && Date.iso8601(item["date"]) < today
        return "past_event"
      end
      "matched"
    end
  end
end
