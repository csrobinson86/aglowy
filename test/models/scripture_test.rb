require "test_helper"

class ScriptureTest < ActiveSupport::TestCase
  test "Isaiah 41:10" do
    scripture = Scripture.parse("Isaiah 41:10")

    assert_equal 23, scripture.book_number
    assert_equal "Isaiah", scripture.book
    assert_equal 41, scripture.chapter
    assert_equal 10..10, scripture.verses
    assert_equal "Isaiah 41:10", scripture.to_s
  end

  test "isa 41:10-13" do
    scripture = Scripture.parse("isa 41:10-13")

    assert_equal [ 23, 41, 10, 13 ], [ scripture.book_number, scripture.chapter, scripture.verse_start, scripture.verse_end ]
    assert_equal "Isaiah 41:10-13", scripture.to_s
  end

  test "Ps 23" do
    scripture = Scripture.parse("Ps 23")

    assert_equal 19, scripture.book_number
    assert_equal 23, scripture.chapter
    assert_nil scripture.verses
    assert_equal "Psalm 23", scripture.to_s
  end

  test "1 Pet 5:7" do
    scripture = Scripture.parse("1 Pet 5:7")

    assert_equal [ 60, "1 Peter", 5, 7..7 ], [ scripture.book_number, scripture.book, scripture.chapter, scripture.verses ]
  end

  test "Song of Solomon 2:4" do
    scripture = Scripture.parse("Song of Solomon 2:4")

    assert_equal [ 22, 2, 4..4 ], [ scripture.book_number, scripture.chapter, scripture.verses ]
    assert_equal "Song of Solomon 2:4", scripture.to_s
  end

  test "Philippians 4:6, 7 stores 6 to 7" do
    scripture = Scripture.parse("Philippians 4:6, 7")

    assert_equal [ 50, 4, 6, 7 ], [ scripture.book_number, scripture.chapter, scripture.verse_start, scripture.verse_end ]
  end

  test "Hezekiah 1:1 is nil" do
    assert_nil Scripture.parse("Hezekiah 1:1")
  end

  test "Isaiah with no chapter is nil" do
    assert_nil Scripture.parse("Isaiah")
  end

  test "41:10, 13 stores 10 to 13" do
    assert_equal 10..13, Scripture.parse("Isaiah 41:10, 13").verses
  end

  test "names and abbreviations in any case, with or without spaces and full stops" do
    assert_equal [ 19 ] * 4, [ "Psalm 23", "PSALMS 23", "ps. 23", "Ps 23" ].map { Scripture.parse(it).book_number }
    assert_equal [ 60 ] * 4, [ "1 Peter 5:7", "1Pet 5:7", "1 pet. 5:7", "1Pe 5:7" ].map { Scripture.parse(it).book_number }
    assert_equal 1, Scripture.parse("  Genesis   1:1 ").book_number
    assert_equal 66, Scripture.parse("Rev 21:4").book_number
  end

  test "the book list is the 66 books in Bible order" do
    assert_equal 66, Scripture::BOOKS.size
    assert_equal %w[ Genesis Malachi Matthew Revelation ], Scripture::BOOKS.values_at(0, 38, 39, 65).map(&:first)
  end

  test "every name and abbreviation points to one book" do
    keys = Scripture::BOOKS.flatten.map { Scripture.key(it) }

    assert_equal keys.uniq, keys
  end

  test "nonsense numbers are nil" do
    [ "Isaiah 0:1", "Isaiah 41:0", "Isaiah 41:13-10", "Isaiah 41:", "Isaiah 41:a", "Isaiah 41:10,", "Isaiah four", "Psalm 151", "Psalm 119:177", "", nil ].each do |reference|
      assert_nil Scripture.parse(reference), reference.inspect
    end
  end

  test "a one-chapter book is cited by verse" do
    jude = Scripture.parse("Jude 3")

    assert_equal [ 65, 1, 3..3 ], [ jude.book_number, jude.chapter, jude.verses ]
    assert_equal "Jude 3", jude.to_s
    assert_equal "Philemon 4-6", Scripture.parse("Phm 1:4-6").to_s
  end

  test "an en dash range" do
    assert_equal 10..13, Scripture.parse("Isaiah 41:10–13").verses
  end
end
