# A link the AI used, and which of them a feature may show (docs/design/ai.md, Ai::SourceLink). Only a page the
# search itself returned, on an allowed host, is kept, so the AI can't invent an article. Nothing here requests a
# page: fetching jw.org is what its terms forbid (Traps).
class Ai::SourceLink
  # [{ url:, title: }], once each, for the candidates (URLs, or hashes with a url) that are safe, on an allowed host
  # and in the search results. The title comes from the search result, and nothing else from it is kept.
  def self.keep(candidates, search_results:, allowed_hosts:)
    titles = search_results.each_with_object({}) { |result, found| found[new(result[:url], allowed_hosts:).url] ||= result[:title] }

    candidates.filter_map { new(it.is_a?(Hash) ? it[:url] : it, allowed_hosts:).url }.uniq
              .filter_map { |url| { url: url, title: titles[url] } if titles.key?(url) }
  end

  def initialize(url, allowed_hosts:)
    @url, @allowed_hosts = url.to_s, allowed_hosts
  end

  # The URL without its fragment or utm_ parameters, or nil unless it's https, with no user or port, and its host is
  # exactly an allowed one.
  def url
    scheme, userinfo, host, port, _registry, path, _opaque, query = URI.split(@url)
    return unless scheme.to_s.downcase == "https" && userinfo.nil? && port.nil? && host.to_s.downcase.in?(@allowed_hosts)

    "https://#{host.downcase}#{path.presence || "/"}#{"?#{without_tracking(query)}" if without_tracking(query)}"
  rescue URI::InvalidURIError
    nil
  end

  private
    def without_tracking(query)
      query.to_s.split("&").reject { it.downcase.start_with?("utm_") }.join("&").presence
    end
end
