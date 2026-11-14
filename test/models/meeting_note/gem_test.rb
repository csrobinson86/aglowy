require "test_helper"

class MeetingNote::GemTest < ActiveSupport::TestCase
  test "parses on assignment" do
    gem = meeting_notes(:head_midweek).gems.new(position: 3, scripture: "isa 41:10-13")

    assert gem.valid?
    assert_equal "isa 41:10-13", gem.scripture
    assert_equal [ 23, 41, 10, 13 ], [ gem.book_number, gem.chapter, gem.verse_start, gem.verse_end ]
  end

  test "a whole chapter leaves the verses empty" do
    gem = meeting_note_gems(:head_strength).tap { it.scripture = "Psalm 23" }

    assert_equal [ 19, 23, nil, nil ], [ gem.book_number, gem.chapter, gem.verse_start, gem.verse_end ]
  end

  test "an unparseable reference is an error on scripture" do
    gem = meeting_note_gems(:head_strength).tap { it.scripture = "Hezekiah 1:1" }

    assert_not gem.valid?
    assert_equal [ "Use a reference like Isaiah 41:10." ], gem.errors[:scripture]
    assert_nil gem.book_number
  end

  test "a blank reference is an error on scripture" do
    gem = meeting_notes(:head_midweek).gems.new(position: 3)

    assert_not gem.valid?
    assert_equal [ "Use a reference like Isaiah 41:10." ], gem.errors[:scripture]
  end

  test "insight is stored encrypted" do
    gem = meeting_note_gems(:head_strength)
    gem.update!(insight: "Jehovah holds on to me when I feel weak")

    raw = MeetingNote::Gem.connection.select_value(MeetingNote::Gem.where(id: gem.id).select(:insight).to_sql)

    assert_not_includes raw, "feel weak"
    assert_equal "Jehovah holds on to me when I feel weak", gem.reload.insight
  end

  test "reference is the normalised reference" do
    assert_equal "Philippians 4:6-7", meeting_note_gems(:head_anxiety).reference.to_s
  end

  test "a gem on a weekend note is invalid" do
    gem = meeting_notes(:head_weekend).gems.new(position: 1, scripture: "Isaiah 41:10")

    assert_not gem.valid?
    assert_includes gem.errors[:meeting_note], "must be a Life and Ministry note"
  end

  test "requires a position" do
    gem = meeting_notes(:head_midweek).gems.new(scripture: "Isaiah 41:10")

    assert_not gem.valid?
    assert_includes gem.errors[:position], "can't be blank"
  end

  test "requires a note" do
    gem = MeetingNote::Gem.new(position: 1, scripture: "Isaiah 41:10")

    assert_not gem.valid?
    assert_includes gem.errors[:meeting_note], "must exist"
  end

  test "a note's gems are ordered by position" do
    assert_equal [ meeting_note_gems(:head_strength), meeting_note_gems(:head_anxiety) ], meeting_notes(:head_midweek).gems
  end

  test "fixture insights read back decrypted" do
    assert_includes meeting_note_gems(:head_anxiety).insight, "peace"
  end

  test "destroying a note deletes its gems" do
    assert_difference -> { MeetingNote::Gem.count }, -2 do
      meeting_notes(:head_midweek).destroy!
    end
  end

  test "database: book_number 67 raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { meeting_note_gems(:head_strength).update_column(:book_number, 67) }
  end

  test "database: book_number 0 raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { meeting_note_gems(:head_strength).update_column(:book_number, 0) }
  end

  test "database: chapter 0 raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { meeting_note_gems(:head_strength).update_column(:chapter, 0) }
  end

  test "database: a verse_start without a verse_end raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { meeting_note_gems(:head_strength).update_column(:verse_end, nil) }
  end

  test "database: verse_start 0 raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { meeting_note_gems(:head_strength).update_column(:verse_start, 0) }
  end

  test "database: a backwards verse range raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { meeting_note_gems(:head_anxiety).update_column(:verse_start, 8) }
  end

  test "database: a gem without a scripture raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { meeting_note_gems(:head_strength).update_column(:scripture, nil) }
  end

  test "database: a gem without a book_number raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { meeting_note_gems(:head_strength).update_column(:book_number, nil) }
  end

  test "database: a gem without a chapter raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { meeting_note_gems(:head_strength).update_column(:chapter, nil) }
  end

  test "database: a gem without a position raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { meeting_note_gems(:head_strength).update_column(:position, nil) }
  end

  test "database: a gem for a missing note raises InvalidForeignKey" do
    assert_raises(ActiveRecord::InvalidForeignKey) { meeting_note_gems(:head_strength).update_column(:meeting_note_id, SecureRandom.uuid_v7) }
  end

  test "database: deleting a note deletes its gems" do
    assert_difference -> { MeetingNote::Gem.count }, -2 do
      MeetingNote.where(id: meeting_notes(:head_midweek).id).delete_all
    end
  end
end
