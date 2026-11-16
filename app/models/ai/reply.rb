# What Chat#ask_within_purpose returns: the reply's fields and the pages its web search used
# (docs/design/ai.md, Conversations). Untrusted text, still to go through the checks before anyone sees it.
class Ai::Reply
  def initialize(message)
    @message = message
  end

  def parsed
    @parsed ||= @message.parsed || {}
  end

  def off_topic?
    parsed["off_topic"] == true
  end

  # [{ url:, title:, cited_text: [excerpts] }], one per page the search returned or a citation named. The excerpts
  # are only for the copy check: never store or show them (docs/design/ai.md, Traps).
  def sources
    @sources ||= pages.map do |url, title|
      { url: url, title: title, cited_text: citations.filter_map { it.cited_text.presence if it.url == url }.uniq }
    end
  end

  private
    def citations = @message.citations

    def pages
      found = @message.web_sources.to_h { [ it.url, it.title ] }
      citations.each { found[it.url] ||= it.title if it.url }
      found
    end
end
