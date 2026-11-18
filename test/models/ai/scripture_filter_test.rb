require "test_helper"

class Ai::ScriptureFilterTest < ActiveSupport::TestCase
  test "phil 4:6,7 becomes Philippians 4:6, 7" do
    assert_equal({ "opening" => { "scripture" => "Philippians 4:6, 7", "question" => "What could we tell Jehovah?" } },
                 Ai::ScriptureFilter.keep("opening" => { "scripture" => "phil 4:6,7", "question" => "What could we tell Jehovah?" }))
  end

  test "Hezekiah 3:1 is dropped" do
    assert_equal({ "points" => [ { "heading" => "Jehovah listens" }, { "heading" => "Pray often", "scripture" => "1 Thessalonians 5:17" } ] },
                 Ai::ScriptureFilter.keep("points" => [ { "heading" => "Jehovah listens", "scripture" => "Hezekiah 3:1" }, { "heading" => "Pray often", "scripture" => "1 thess 5:17" } ]))
  end

  test "a URL in a question is stripped" do
    fields = Ai::ScriptureFilter.keep(
      "off_topic" => false,
      "opening" => { "question" => "What does https://www.jw.org/en/bible-teachings/ say? See www.jw.org/en, or wol.jw.org/en/wol/d/r1." }
    )

    assert_equal({ "off_topic" => false, "opening" => { "question" => "What does say? See, or." } }, fields)
  end

  test "a feature's own scripture fields, and list fields that keep each reference that parses" do
    kept = Ai::ScriptureFilter.new(scripture_fields: %w[ passage ], list_fields: %w[ scriptures none ]).keep({ "passage" => "matthew 16:21-23", "scripture" => "Psalm 37:10", "scriptures" => "Genesis 21:5; Hebrews 99:1; heb 6:15",
      "none" => "Not one; nor two", "note" => "Psalm 23" })

    assert_equal({ "passage" => "Matthew 16:21-23", "scripture" => "Psalm 37:10", "scriptures" => "Genesis 21:5; Hebrews 6:15", "note" => "Psalm 23" }, kept)
  end
end
