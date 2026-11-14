require "test_helper"

class MeetingNote::OutlineTest < ActiveSupport::TestCase
  test "version 1 lists the sections and parts in the design doc" do
    midweek = MeetingNote::Outline.new(kind: "midweek", version: 1)

    assert_equal [ [ "Treasures From God's Word", :muted ], [ "Apply Yourself to the Field Ministry", :attention ], [ "Living as Christians", :danger ] ],
      midweek.sections.map { [ it.name, it.dot ] }
    assert_equal [ %w[ talk spiritual_gems bible_reading ], %w[ field_ministry ], %w[ living_part congregation_bible_study ] ],
      midweek.sections.map { it.parts.map(&:key) }
    assert_equal [ %i[ title notes ], %i[ gems ], %i[ notes ], %i[ notes ], %i[ title notes ], %i[ notes ] ], midweek.parts.map(&:fields)
    assert_equal %w[ living_part ], midweek.parts.select(&:repeats?).map(&:key)

    weekend = MeetingNote::Outline.new(kind: "weekend", version: 1)

    assert_equal [ [ "Public Talk", :muted ], [ "Watchtower Study", :danger ] ], weekend.sections.map { [ it.name, it.dot ] }
    assert_equal [ %w[ public_talk ], %w[ watchtower_study ] ], weekend.sections.map { it.parts.map(&:key) }
    assert_equal [ %i[ title speaker notes ], %i[ title notes ] ], weekend.parts.map(&:fields)
    assert_empty weekend.parts.select(&:repeats?)
  end

  test "each part has a label" do
    assert_equal [ "Talk", "Spiritual Gems", "Bible Reading", "Field Ministry", "Living as Christians part", "Congregation Bible Study" ],
      MeetingNote::Outline.new(kind: "midweek", version: 1).parts.map(&:label)
    assert_equal [ "Public Talk", "Watchtower Study" ], MeetingNote::Outline.new(kind: "weekend", version: 1).parts.map(&:label)
  end

  test "part finds a part by key, nil when it isn't in the outline" do
    outline = MeetingNote::Outline.new(kind: "weekend", version: 1)

    assert_equal "Public Talk", outline.part("public_talk").label
    assert_nil outline.part("talk")
  end

  test "an unknown kind has no sections" do
    assert_empty MeetingNote::Outline.new(kind: "assembly", version: 1).sections
  end

  test "an unknown version raises" do
    assert_raises(KeyError) { MeetingNote::Outline.new(kind: "midweek", version: 2) }
  end
end
