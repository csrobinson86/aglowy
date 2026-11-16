# Links the references someone typed by hand, "matt 24:14", in a rich text body (docs/design/scripture-links.md,
# Bible::Linker). It walks the fragment's text nodes, so only text outside links, attachments, code and pre changes,
# and links only what Bible::Reference.parse accepts with a chapter and a verse: "Job 5" and "Acts of kindness" stay text.
class Bible::Linker
  SKIPPED = [ "a", "code", "pre", ActionText::Attachment.tag_name ].freeze
  # A chapter and verse, "24:14", maybe with a range, "8-9" or "8, 9", ending at a word boundary. A hyphen range that
  # isn't one, as in "Gen 1:1-2:3", refuses the whole match rather than leaving a link to its first verse.
  VERSES = /(?<![[:alnum:]:])\d+:\d+(?:(?<range>\s*[-–]\s*\d+|,\s*\d+)|(?!\s*[-–]\s*\d))(?![[:alnum:]]|:\d)/
  # The words a book could be just before the verses: up to four, for "and Song of Solomon" or "read 1 Cor".
  WORD = /(?<![[:alnum:].])[[:alnum:]][[:alpha:].]*/
  WORDS = /(?:#{WORD}\s*){1,4}\z/

  def initialize(content)
    @content = content
  end

  def link
    ActionText::Content.new(content.fragment.update { |source| source.xpath(".//text()").each { link_in(it) } })
  end

  private
    attr_reader :content

    def link_in(node)
      return if node.ancestors.any? { SKIPPED.include?(it.name) }

      html, rest = +"", node.text
      while (reference, start, finish = next_reference(rest))
        html << ERB::Util.html_escape(rest[...start]) << ActionText::Attachment.from_attachable(reference).to_html
        rest = rest[finish..]
      end
      node.replace(html << ERB::Util.html_escape(rest)) unless html.empty?
    end

    # The first reference in the text, with where it starts and ends. Editors type a non-breaking space as often as a
    # space, so both count. The longest book that parses wins, so "1 John 3:16" is 1 John and not John. Two verses
    # joined by a comma that don't parse, as in "Ps 37:8, 10", fall back to the first; a hyphen range never does.
    def next_reference(text)
      text = text.tr("\u00A0", " ")
      text.to_enum(:scan, VERSES).each do
        verses = Regexp.last_match

        book_starts(text[...verses.begin(0)]).product([ verses.end(0), (verses.begin(:range) if verses[:range]&.start_with?(",")) ].compact).each do |start, finish|
          reference = Bible::Reference.parse(text[start...finish])
          return [ reference, start, finish ] if reference&.first_verse
        end
      end
      nil
    end

    # Where each word just before the verses starts, the earliest first.
    def book_starts(before)
      words = before.match(WORDS) or return []
      words[0].to_enum(:scan, WORD).map { words.begin(0) + Regexp.last_match.begin(0) }
    end
end
