# A Bible reference such as "Isaiah 41:10", parsed into book, chapter and verses so gems can sort in
# Bible order. A whole chapter ("Psalm 23") has no verses; a list ("Philippians 4:6, 7") keeps its first to last.
class Scripture
  # The 66 books in Bible order, so a book's number is its index plus one. Each book's name comes
  # first, then its common abbreviations, including the ones jw.org uses.
  BOOKS = [
    [ "Genesis", "Gen", "Ge" ],
    [ "Exodus", "Exod", "Ex" ],
    [ "Leviticus", "Lev", "Le" ],
    [ "Numbers", "Num", "Nu" ],
    [ "Deuteronomy", "Deut", "De" ],
    [ "Joshua", "Josh", "Jos" ],
    [ "Judges", "Judg", "Jg" ],
    [ "Ruth", "Ru" ],
    [ "1 Samuel", "1 Sam", "1 Sa" ],
    [ "2 Samuel", "2 Sam", "2 Sa" ],
    [ "1 Kings", "1 Kgs", "1 Ki" ],
    [ "2 Kings", "2 Kgs", "2 Ki" ],
    [ "1 Chronicles", "1 Chron", "1 Chr", "1 Ch" ],
    [ "2 Chronicles", "2 Chron", "2 Chr", "2 Ch" ],
    [ "Ezra", "Ezr" ],
    [ "Nehemiah", "Neh", "Ne" ],
    [ "Esther", "Esth", "Es" ],
    [ "Job" ],
    [ "Psalms", "Psalm", "Psa", "Ps" ],
    [ "Proverbs", "Prov", "Pr" ],
    [ "Ecclesiastes", "Eccl", "Ec" ],
    [ "Song of Solomon", "Song of Songs", "Song", "Ca" ],
    [ "Isaiah", "Isa" ],
    [ "Jeremiah", "Jer" ],
    [ "Lamentations", "Lam", "La" ],
    [ "Ezekiel", "Ezek", "Eze" ],
    [ "Daniel", "Dan", "Da" ],
    [ "Hosea", "Hos", "Ho" ],
    [ "Joel", "Joe" ],
    [ "Amos", "Am" ],
    [ "Obadiah", "Obad", "Ob" ],
    [ "Jonah", "Jon" ],
    [ "Micah", "Mic" ],
    [ "Nahum", "Nah", "Na" ],
    [ "Habakkuk", "Hab" ],
    [ "Zephaniah", "Zeph", "Zep" ],
    [ "Haggai", "Hag" ],
    [ "Zechariah", "Zech", "Zec" ],
    [ "Malachi", "Mal" ],
    [ "Matthew", "Matt", "Mt" ],
    [ "Mark", "Mk", "Mr" ],
    [ "Luke", "Lk", "Lu" ],
    [ "John", "Jn", "Joh" ],
    [ "Acts", "Ac" ],
    [ "Romans", "Rom", "Ro" ],
    [ "1 Corinthians", "1 Cor", "1 Co" ],
    [ "2 Corinthians", "2 Cor", "2 Co" ],
    [ "Galatians", "Gal", "Ga" ],
    [ "Ephesians", "Eph" ],
    [ "Philippians", "Phil", "Php" ],
    [ "Colossians", "Col" ],
    [ "1 Thessalonians", "1 Thess", "1 Th" ],
    [ "2 Thessalonians", "2 Thess", "2 Th" ],
    [ "1 Timothy", "1 Tim", "1 Ti" ],
    [ "2 Timothy", "2 Tim", "2 Ti" ],
    [ "Titus", "Tit" ],
    [ "Philemon", "Philem", "Phm" ],
    [ "Hebrews", "Heb" ],
    [ "James", "Jas" ],
    [ "1 Peter", "1 Pet", "1 Pe" ],
    [ "2 Peter", "2 Pet", "2 Pe" ],
    [ "1 John", "1 Jn", "1 Jo" ],
    [ "2 John", "2 Jn", "2 Jo" ],
    [ "3 John", "3 Jn", "3 Jo" ],
    [ "Jude" ],
    [ "Revelation", "Rev", "Re" ]
  ].freeze

  # Psalms has the most chapters and Psalm 119 the most verses, so anything larger isn't a real reference.
  MOST_CHAPTERS = 150
  MOST_VERSES = 176

  # These books have one chapter and are cited by verse: "Jude 3" is Jude 1:3.
  ONE_CHAPTER_BOOKS = [ "Obadiah", "Philemon", "2 John", "3 John", "Jude" ].freeze

  class << self
    # The book name comes off the front first, then the numbers: "41:10", "41:10-13", "41:10, 13" or a whole "23".
    # Returns nil for anything that isn't a reference to one of the 66 books.
    def parse(reference)
      name, numbers = reference.to_s.squish.match(/\A(.*?[[:alpha:].]) ?(\d.*)\z/)&.captures
      book_number = book_numbers[key(name)] if name
      return unless book_number

      chapter_text, verses_text = numbers.split(":", 2)
      chapter_text, verses_text = "1", chapter_text if verses_text.nil? && ONE_CHAPTER_BOOKS.include?(BOOKS[book_number - 1].first)
      chapter = number(chapter_text, up_to: MOST_CHAPTERS)
      verses = verse_numbers(verses_text) if verses_text
      return if chapter.nil? || (verses_text && verses.nil?)

      new(book_number: book_number, chapter: chapter, verse_start: verses&.min, verse_end: verses&.max)
    end

    # Names compare in lower case without spaces or full stops, so "1 Pet.", "1pet" and "1 PET" match.
    def key(name)
      name.downcase.delete(" .")
    end

    private
      def book_numbers
        @book_numbers ||= BOOKS.each.with_index(1).flat_map { |names, number| names.map { [ key(it), number ] } }.to_h
      end

      # Every verse number in "10", "10-13" or "6, 7", or nil unless each piece is a verse or a forward range.
      def verse_numbers(text)
        pieces = text.split(",", -1).map { |piece| piece.split(/[-–]/, -1).map { number(it, up_to: MOST_VERSES) } }
        pieces.flatten if pieces.any? && pieces.all? { it.size.between?(1, 2) && it.all? && it == it.sort }
      end

      def number(text, up_to:)
        number = text.strip.to_i if text.strip.match?(/\A\d+\z/)
        number if number&.between?(1, up_to)
      end
  end

  attr_reader :book_number, :chapter, :verse_start, :verse_end

  def initialize(book_number:, chapter:, verse_start: nil, verse_end: nil)
    @book_number, @chapter, @verse_start, @verse_end = book_number, chapter, verse_start, verse_end
  end

  def book
    BOOKS[book_number - 1].first
  end

  def verses
    verse_start..verse_end if verse_start
  end

  # "Isaiah 41:10", "Isaiah 41:10-13", "Jude 3", or "Psalm 23": a reference cites one psalm, not "Psalms".
  def to_s
    name = book == "Psalms" ? "Psalm" : book

    if ONE_CHAPTER_BOOKS.include?(book)
      "#{name} #{[ verse_start, verse_end ].uniq.join("-")}"
    elsif verse_start.nil?
      "#{name} #{chapter}"
    elsif verse_start == verse_end
      "#{name} #{chapter}:#{verse_start}"
    else
      "#{name} #{chapter}:#{verse_start}-#{verse_end}"
    end
  end
end
