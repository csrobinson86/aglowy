# A Bible reference, "Psalm 37:8, 9", that links the passage on jw.org (docs/design/scripture-links.md, Models).
# A whole chapter has no verses. It's the Action Text attachable for scripture links: its id is the reference
# itself ("19:37:8-9"), so finding one is a parse and never a query, and GlobalID signs it with no table.
Bible::Reference = Data.define(:book, :chapter, :first_verse, :last_verse) do
  include GlobalID::Identification
  include ActionText::Attachable

  # "psalms 37:8,9", "Ps 37:8-9", "ps 37 8" or "Psalm 23": a book, a chapter, then a verse or two.
  self::PATTERN = /\A\s*(?<book>\d?\s*[[:alpha:]][[:alpha:].\s]*?)\s*(?<chapter>\d+)(?:\s*[:\s]\s*(?<first_verse>\d+)(?:\s*(?<joiner>[-–,])\s*(?<last_verse>\d+))?)?\s*\z/
  self::ID = /\A(?<book>\d+):(?<chapter>\d+)(?::(?<first_verse>\d+)(?:-(?<last_verse>\d+))?)?\z/

  class << self
    # Strict: nil unless the book is named exactly and the chapter and verses exist. A comma joins only two
    # verses in a row ("8, 9"); verses that aren't in a row ("8, 10") aren't supported.
    def parse(text)
      parts = text.to_s.match(self::PATTERN) or return
      book = Bible::Book.match(parts[:book]).find { it.called?(parts[:book]) } or return
      return if parts[:joiner] == "," && parts[:last_verse].to_i != parts[:first_verse].to_i + 1

      existing(book, *parts.values_at(:chapter, :first_verse, :last_verse))
    end

    def find(id)
      parts = id.to_s.match(self::ID)
      reference = existing(Bible::Book.find(parts[:book]), *parts.values_at(:chapter, :first_verse, :last_verse)) if parts

      reference or raise ActiveRecord::RecordNotFound, "Couldn't find Bible reference #{id.inspect}"
    end

    private
      # The reference, if its chapter and verses are in the book. One verse is a range of one.
      def existing(book, chapter, first_verse, last_verse)
        chapter, first_verse = chapter.to_i, first_verse&.to_i
        last_verse = last_verse&.to_i || first_verse
        verses = book.verses_in(chapter)

        new(book, chapter, first_verse, last_verse) if verses && (first_verse.nil? || (first_verse.between?(1, last_verse) && last_verse <= verses))
      end
  end

  def id
    [ book.number, chapter, ([ first_verse, last_verse ].uniq.join("-") if first_verse) ].compact.join(":")
  end

  # Our way: "Psalm" for one psalm, "8, 9" for two verses in a row, "8-11" for more, and "Psalm 23" for a chapter.
  def to_s
    first_verse ? "#{book.single} #{chapter}:#{verses_text}" : "#{book.single} #{chapter}"
  end

  # Partials are given an ActionText::Attachment that stands in for the reference, and its to_s is HTML.
  def text
    to_s
  end

  # The passage in the New World Translation (Study Edition), in the format JW Library's share links use.
  # A whole chapter runs from verse 1 to its last verse.
  def jw_url
    verses = [ first_verse || 1, last_verse || book.verses_in(chapter) ].uniq
    "https://www.jw.org/finder?wtlocale=E&pub=nwtsty&bible=#{verses.map { bible_code(it) }.join("-")}"
  end

  def attachable_content_type
    "application/vnd.actiontext.scripture"
  end

  def to_attachable_partial_path
    "bible/references/reference"
  end

  # Action Text's hook for the attachment as an editor shows it.
  def to_trix_content_attachment_partial_path
    "bible/references/editor"
  end

  # So plain-text exports and search read "Psalm 37:8, 9".
  def attachable_plain_text_representation(_caption = nil)
    to_s
  end

  private
    def verses_text
      case last_verse - first_verse
      when 0 then first_verse.to_s
      when 1 then "#{first_verse}, #{last_verse}"
      else "#{first_verse}-#{last_verse}"
      end
    end

    # BBCCCVVV: the book, chapter and verse padded to 2, 3 and 3 digits.
    def bible_code(verse)
      format("%02d%03d%03d", book.number, chapter, verse)
    end
end
