# Scripture references in a reply, written our way, and no web addresses in its text (docs/design/ai.md, Scripture
# references and Traps). A scripture field that isn't a real reference is dropped, so the AI can't invent a verse,
# and links reach a page only through Ai::SourceLink.
class Ai::ScriptureFilter
  # A web address: with a scheme, starting www., or a host name followed by a path. The stop after it isn't part of it.
  URL = %r{\b(?:(?:[a-z][a-z0-9+.-]*://|www\.)\S*|(?:[a-z0-9-]+\.)+[a-z]{2,}/\S*)(?<![.,!?;:)\]"”’])}i

  # The fields (nested hashes and arrays) with each scripture field as Bible::Reference#to_s, or gone when it doesn't
  # parse, and every web address taken out of the other strings.
  def self.keep(fields)
    new.keep(fields)
  end

  def keep(value)
    case value
    when Hash then value.each_with_object({}) { |(key, field), kept| keep_field(kept, key, field) }
    when Array then value.map { keep(it) }
    when String then value.match?(URL) ? value.gsub(URL, "").gsub(/\s+(?=[.,!?;:])/, "").squish : value
    else value
    end
  end

  private
    def keep_field(kept, key, value)
      if key.to_s != "scripture"
        kept[key] = keep(value)
      elsif (reference = Bible::Reference.parse(value))
        kept[key] = reference.to_s
      end
    end
end
