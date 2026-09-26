module Radar
  module Filter
    EVENT_WORDS = /\b(?:fuar\p{L}*|buluş\p{L}*|bulus\p{L}*|konferans\p{L}*|kongre\p{L}*|zirve\p{L}*|networking|meetup|conference\p{L}*|summit\p{L}*|expo|festival\p{L}*|çalıştay\p{L}*|calistay\p{L}*|sempozyum\p{L}*|forum\p{L}*|b2b|heyet\p{L}*|tedarikçi günü|tedarikci gunu|iş görüşme\p{L}*|is gorusme\p{L}*|iş toplant\p{L}*|is toplant\p{L}*)\b/u

    def self.event_candidate?(text)
      normalize(text).match?(EVENT_WORDS)
    end

    def self.meeting_decision(item, today: Date.today)
      return "not_meeting" unless item["type"] == "event"
      # Trust the quoted source, not a model-generated reason like 'may be useful for ERP'.
      return "no_meeting_evidence" unless event_candidate?(item["evidence"])
      return "missing_event_date" unless item["date"]
      return "past_event" if Date.iso8601(item["date"]) < today
      title = normalize(item["title"])
      return "administrative_notice" if title.match?(/(?:belge\p{L}*|belgelendirme|sertifika|mevzuat|tebliğ|teblig|sirküler|sirkuler|aidat|vergi|gümrük|gumruk|ihale)/) && !event_candidate?(title)
      return "past_report" if normalize(item["evidence"]).match?(/\b(?:gerçekleştirildi|gerceklestirildi|düzenlendi|duzenlendi|gerçekleşti|gerceklesti|sona erdi)\b/)
      nil
    end
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
      if profile.fetch("meeting_only", false)
        rejection = meeting_decision(item, today: today)
        return rejection if rejection
      end
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
