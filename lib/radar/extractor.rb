require "nokogiri"

module Radar
  class Robots
    def initialize(text)
      @groups = []
      agents, rules = [], []
      text.each_line do |line|
        key, value = line.sub(/#.*/, "").strip.split(":", 2)
        next unless value
        value = value.strip
        if key.downcase == "user-agent"
          unless rules.empty?
            @groups << [agents, rules]
            agents, rules = [], []
          end
          agents << value.downcase
        elsif %w[allow disallow].include?(key.downcase) && !agents.empty? && !value.empty?
          rules << [key.downcase, value]
        end
      end
      @groups << [agents, rules]
    end

    def allowed?(url)
      specific = @groups.select { |agents, _| agents.any? { |a| a != "*" && "firsatradari".include?(a) } }
      chosen = specific.empty? ? @groups.select { |agents, _| agents.include?("*") } : specific
      target = URI(url).request_uri
      matches = chosen.flat_map(&:last).select do |_, path|
        expr = Regexp.escape(path).gsub('\\*', '.*').sub(/\\\$$/, '$')
        target.match?(Regexp.new("^#{expr}"))
      end
      best = matches.max_by { |kind, path| [path.delete("*$").length, kind == "allow" ? 1 : 0] }
      best.nil? || best.first == "allow"
    end
  end

  class Extractor
    VERSION = 2
    def self.call(body, url, content_type)
      charset = content_type[/charset\s*=\s*["']?([\w-]+)/i, 1] || body.b[/charset\s*=\s*["']?([\w-]+)/i, 1] || "UTF-8"
      encoding = Encoding.find(charset) rescue Encoding::UTF_8
      text = body.dup.force_encoding(encoding).encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      if content_type.include?("xml") || text.lstrip.start_with?("<?xml")
        xml = Nokogiri::XML(text) { |c| c.nonet }
        links = xml.xpath("//*[local-name()='loc']").map(&:text).first(1000)
        return { "text" => "", "links" => valid_links(links, url), "source_tags" => [], "extractor_version" => VERSION }
      end
      raise WorkError.new("unsupported_content", permanent: true) unless content_type.include?("html") || content_type.include?("text/plain")
      doc = Nokogiri::HTML(text)
      title = doc.at_css("title")&.text.to_s
      if title.match?(/just a moment|attention required|access denied|verify.*human/i) || doc.at_css("#challenge-form, #cf-challenge-running")
        raise WorkError.new("challenge_page", permanent: true)
      end
      links = ranked_links(doc, url)
      structured = doc.css('script[type="application/ld+json"]').map(&:text).join("\n")
      doc.css("script,style,nav,footer,header,aside,noscript,form,svg").remove
      articles = doc.css("article")
      root = doc.at_css("main") || (articles.first if articles.size == 1) || doc.at_css("body") || doc
      plain = root.xpath(".//text()").map(&:text).join(" ").gsub(/\s+/, " ").strip
      plain = [title, plain, structured.empty? ? nil : "JSON-LD: #{structured}"].compact.join("\n")
      { "text" => plain, "links" => links, "source_tags" => plain.scan(/#[\p{L}\p{N}_]+/).uniq.first(50), "extractor_version" => VERSION }
    end

    def self.valid_links(links, url)
      links.filter_map { |link| URL.canonical(link, url) rescue nil }.uniq
    end

    # Generic URL + anchor ranking; no site-specific selectors or keyword gate on content.
    def self.ranked_links(doc, url)
      scored = doc.css("a[href]").first(3000).filter_map.with_index do |node, index|
        link = URL.canonical(node["href"], url) rescue next
        path = URI(link).path
        next if path.match?(/\.(?:jpg|jpeg|png|gif|svg|webp|zip|pdf|mp4|css|js)\z/i)
        text = Filter.normalize("#{URI.decode_www_form_component(path).scrub} #{node.text}")
        score = 0
        score += 10 if text.match?(/etkinlik|event|fuar|fair|expo|zirve|summit|kongre|conference|konferans|b2b|network|bulusma|buluşma|tedarikçi|tedarikci/)
        score += 4 if text.match?(/takvim|calendar|duyuru|announcement|haber|news/)
        score += 2 if text.match?(/\b20\d{2}\b/)
        score -= 30 if text.match?(/hakkimizda|hakkımızda|about|iletisim|iletişim|contact|gizlilik|privacy|login|giris|giriş|cookie|kvkk/)
        score -= 20 if path == "/" || path.match?(%r{\A/(?:tr|en)/?\z})
        next if score < 0 || link == url
        [link, score, index]
      end
      scored.sort_by { |_, score, index| [-score, index] }.map(&:first).uniq
    end
  end
end
