# One of the 66 books of the Bible, read once from config/bible.yml (docs/design/scripture-links.md, The canon data).
# A book's verses hold the verse count of each chapter, so their length is its chapter count.
Bible::Book = Data.define(:number, :name, :single, :abbreviations, :verses) do
  class << self
    def all
      @all ||= YAML.load_file(Rails.root.join("config/bible.yml"), freeze: true).map { new(**it.symbolize_keys) }.freeze
    end

    def find(number)
      all.find { it.number == Integer(number.to_s, 10, exception: false) } or raise ActiveRecord::RecordNotFound, "Couldn't find Bible book #{number.inspect}"
    end

    # The books the text could be the start of, in canonical order.
    def match(text)
      all.select { it.matches?(text) }
    end

    # Lower case, without dots or spaces, as abbreviations are written in config/bible.yml.
    def normalize(text)
      text.to_s.downcase.gsub(/[.\s]/, "")
    end
  end

  def chapters
    verses.size
  end

  def verses_in(chapter)
    verses[chapter - 1] if chapter.between?(1, chapters)
  end

  # Whether the text starts this book's name or one of its abbreviations: "1 cor", "1cor." and "1Co" all start
  # 1 Corinthians. A numbered book's name counts without its number too, so "p" starts 1 and 2 Peter.
  def matches?(text)
    prefix = self.class.normalize(text)
    [ *names, self.class.normalize(name.sub(/\A\d /, "")) ].any? { it.start_with?(prefix) }
  end

  # Whether the text is exactly this book's name or one of its abbreviations: "Ps" and "psalms." are Psalms,
  # but "psal" is nothing.
  def called?(text)
    names.include?(self.class.normalize(text))
  end

  private
    def names
      [ name, single, *abbreviations ].map { self.class.normalize(it) }
    end
end
