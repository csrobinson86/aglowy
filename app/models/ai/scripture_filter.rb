# Scripture references in a reply, written our way, and no web addresses in its text (docs/design/ai.md, Scripture
# references and Traps). A scripture field that isn't a real reference is dropped, so the AI can't invent a verse,
# and links reach a page only through Ai::SourceLink.
class Ai::ScriptureFilter
  # A meeting part's sample wording gives a scripture to read aloud after a line in read (docs/design/meeting-parts.md).
  SCRIPTURE_FIELDS = %w[ scripture read ].freeze
  # A web address: with a scheme, starting www., or a host name followed by a path. The stop after it isn't part of it.
  URL = %r{\b(?:(?:[a-z][a-z0-9+.-]*://|www\.)\S*|(?:[a-z0-9-]+\.)+[a-z]{2,}/\S*)(?<![.,!?;:)\]"”’])}i

  # The fields (nested hashes and arrays) with each scripture field as Bible::Reference#to_s, or gone when it doesn't
  # parse, and every web address taken out of the other strings.
  def self.keep(fields)
    new.keep(fields)
  end

  # A feature with other names for its scripture fields gives them; list_fields hold several references, separated by
  # semicolons, and keep the ones that parse.
  def initialize(scripture_fields: SCRIPTURE_FIELDS, list_fields: [])
    @scripture_fields, @list_fields = scripture_fields, list_fields
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
      if key.to_s.in?(@list_fields)
        references = value.to_s.split(";").filter_map { Bible::Reference.parse(it) }
        kept[key] = references.join("; ") if references.any?
      elsif !key.to_s.in?(@scripture_fields)
        kept[key] = keep(value)
      elsif (reference = Bible::Reference.parse(value))
        kept[key] = reference.to_s
      end
    end
end
