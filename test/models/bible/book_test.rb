require "test_helper"

class Bible::BookTest < ActiveSupport::TestCase
  test "there are 66 books in order" do
    books = Bible::Book.all

    assert_equal (1..66).to_a, books.map(&:number)
    assert_equal [ "Genesis", "Exodus" ], books.first(2).map(&:name)
    assert_equal [ "Jude", "Revelation" ], books.last(2).map(&:name)
  end

  test "the books are loaded once" do
    assert_same Bible::Book.all, Bible::Book.all
  end

  test "Psalms has 150 chapters, and Psalm 37 has 40 verses" do
    psalms = Bible::Book.find(19)

    assert_equal "Psalms", psalms.name
    assert_equal "Psalm", psalms.single
    assert_equal 150, psalms.chapters
    assert_equal 40, psalms.verses_in(37)
  end

  test "a chapter outside the book has no verses" do
    psalms = Bible::Book.find(19)

    assert_nil psalms.verses_in(0)
    assert_nil psalms.verses_in(151)
  end

  test "1 cor, 1cor. and 1Co all match 1 Corinthians" do
    corinthians = Bible::Book.find(46)

    assert_equal [ corinthians ], Bible::Book.match("1 cor")
    assert_equal [ corinthians ], Bible::Book.match("1cor.")
    assert_equal [ corinthians ], Bible::Book.match("1Co")
  end

  test "p matches Psalms, Proverbs, Philippians, Philemon, 1 Peter and 2 Peter, in canonical order" do
    assert_equal [ "Psalms", "Proverbs", "Philippians", "Philemon", "1 Peter", "2 Peter" ], Bible::Book.match("p").map(&:name)
  end

  test "a book's own full name always matches" do
    assert_equal [ "Acts" ], Bible::Book.match("Acts").map(&:name)
    assert_equal [ "Song of Solomon" ], Bible::Book.match("song of solomon").map(&:name)
  end

  test "text that starts no book's name matches nothing" do
    assert_empty Bible::Book.match("Hezekiah")
  end

  test "no abbreviation belongs to two books" do
    books = YAML.load_file(Rails.root.join("config/bible.yml"))
    names = books.flat_map { |book| [ book["name"], book["single"], *book["abbreviations"] ].map { it.downcase.delete(" .") }.uniq }

    assert_equal 66, books.size
    assert_empty names.tally.select { |_name, count| count > 1 }.keys
  end

  test "abbreviations that collide or read as ordinary words are left out" do
    abbreviations = YAML.load_file(Rails.root.join("config/bible.yml")).flat_map { it["abbreviations"] }

    assert_empty abbreviations & %w[ jo am is acts ]
    assert_not_includes Bible::Book.find(29).abbreviations, "job"
  end

  test "each book's verse counts give its chapters" do
    assert_equal 1189, Bible::Book.all.sum(&:chapters)
    assert_equal 31_089, Bible::Book.all.sum { it.verses.sum }
  end

  test "a verse the NWT leaves out but keeps the number of still counts" do
    assert_equal 27, Bible::Book.find(40).verses_in(17)
  end

  test "a chapter ends where the NWT's verse numbers end" do
    assert_equal 52, Bible::Book.find(43).verses_in(7)
    assert_equal 8, Bible::Book.find(41).verses_in(16)
  end

  test "a chapter starts where the NWT's verse numbers start" do
    assert_equal 12, Bible::Book.find(43).first_verse_in(8)
    assert_equal 1, Bible::Book.find(43).first_verse_in(7)
  end

  test "find raises RecordNotFound for a number that isn't a book" do
    assert_raises(ActiveRecord::RecordNotFound) { Bible::Book.find(67) }
    assert_raises(ActiveRecord::RecordNotFound) { Bible::Book.find(0) }
    assert_raises(ActiveRecord::RecordNotFound) { Bible::Book.find("bad") }
  end

  test "find takes the number as text" do
    assert_equal "Psalms", Bible::Book.find("19").name
  end
end
