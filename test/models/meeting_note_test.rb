require "test_helper"

class MeetingNoteTest < ActiveSupport::TestCase
  test "starting a midweek note creates its six parts in order" do
    note = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))

    assert_equal %w[ talk spiritual_gems bible_reading field_ministry living_part congregation_bible_study ], note.parts.map(&:key)
    assert_equal [ 1, 2, 3, 4, 5, 6 ], note.parts.map(&:position)
    assert_equal 1, note.outline_version
  end

  test "starting a weekend note creates its two parts in order" do
    note = users(:spouse).start_meeting_note(kind: "weekend", week_of: Date.new(2026, 11, 16))

    assert_equal %w[ public_talk watchtower_study ], note.reload.parts.map(&:key)
  end

  test "starting it twice returns the same note" do
    first = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))

    assert_no_difference -> { MeetingNote.count } do
      assert_no_difference -> { MeetingNote::Part.count } do
        assert_equal first, users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 18))
      end
    end
  end

  test "starting a note that exists from the fixtures returns it with its parts untouched" do
    assert_equal meeting_notes(:head_midweek), users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    assert_equal 6, meeting_notes(:head_midweek).parts.count
  end

  test "starting a note of an unknown kind is refused" do
    assert_no_difference -> { MeetingNote.count } do
      assert_raises(ActiveRecord::RecordInvalid) { users(:spouse).start_meeting_note(kind: "assembly", week_of: Date.new(2026, 11, 16)) }
    end
  end

  test "a Sunday week_of becomes that week's Monday" do
    note = users(:spouse).start_meeting_note(kind: "weekend", week_of: Date.new(2026, 11, 22))

    assert_equal Date.new(2026, 11, 16), note.week_of
  end

  test "program_url for the week of 29 June 2026 ends in /2026/27" do
    note = MeetingNote.new(kind: "midweek", week_of: Date.new(2026, 6, 29))

    assert_equal "https://wol.jw.org/en/wol/meetings/r1/lp-e/2026/27", note.program_url
  end

  test "program_url uses the ISO year for a week that starts in December" do
    assert MeetingNote.new(week_of: Date.new(2026, 12, 28)).program_url.end_with?("/2026/53")
    assert MeetingNote.new(week_of: Date.new(2024, 12, 30)).program_url.end_with?("/2025/1")
  end

  test "display_week for a midweek and a weekend note" do
    assert_equal "Week of November 16–22, 2026", meeting_notes(:head_midweek).display_week
    assert_equal "Weekend of November 21–22, 2026", meeting_notes(:head_weekend).display_week
  end

  test "display_week across a month and across a year" do
    assert_equal "Week of November 30–December 6, 2026", MeetingNote.new(kind: "midweek", week_of: Date.new(2026, 11, 30)).display_week
    assert_equal "Weekend of October 31–November 1, 2026", MeetingNote.new(kind: "weekend", week_of: Date.new(2026, 10, 26)).display_week
    assert_equal "Week of December 28, 2026–January 3, 2027", MeetingNote.new(kind: "midweek", week_of: Date.new(2026, 12, 28)).display_week
  end

  test "outline is the note's kind at its outline version" do
    assert_equal %w[ public_talk watchtower_study ], meeting_notes(:head_weekend).outline.parts.map(&:key)
  end

  test "parts are ordered by position" do
    assert_equal %w[ talk spiritual_gems bible_reading field_ministry living_part congregation_bible_study ], meeting_notes(:head_midweek).parts.map(&:key)
  end

  test "a part key from the other outline is invalid" do
    part = meeting_notes(:head_midweek).parts.new(key: "public_talk", position: 7)

    assert_not part.valid?
    assert_includes part.errors[:key], "is not included in the list"
  end

  test "a second talk is a validation error" do
    part = meeting_notes(:head_midweek).parts.new(key: "talk", position: 7)

    assert_not part.valid?
    assert_includes part.errors[:key], "has already been taken"
  end

  test "a second Living as Christians part is valid" do
    assert meeting_notes(:head_midweek).parts.new(key: "living_part", position: 7).valid?
  end

  test "revise! saves titles and notes, and adds new parts as Living as Christians parts after the others" do
    note = meeting_notes(:head_midweek)

    note.revise!(parts_attributes: [
      { id: meeting_note_parts(:head_talk).id, title: "Jehovah holds on to us" },
      { title: "Second part" }, { title: "Third part" }
    ])

    assert_equal "Jehovah holds on to us", meeting_note_parts(:head_talk).reload.title
    added = note.parts.reload.last(2)
    assert_equal [ [ "living_part", 7, "Second part" ], [ "living_part", 8, "Third part" ] ], added.map { [ it.key, it.position, it.title ] }
  end

  test "revise! removes a Living as Christians part" do
    meeting_notes(:head_midweek).revise!(parts_attributes: [ { id: meeting_note_parts(:head_living_part).id, _destroy: "1" } ])

    assert_not MeetingNote::Part.exists?(meeting_note_parts(:head_living_part).id)
  end

  test "revise! refuses to remove a part that doesn't repeat" do
    note = meeting_notes(:head_midweek)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      note.revise!(parts_attributes: [ { id: meeting_note_parts(:head_bible_reading).id, _destroy: "1" } ])
    end
    assert_includes error.record.errors[:parts], "can't lose Bible Reading"
    assert MeetingNote::Part.exists?(meeting_note_parts(:head_bible_reading).id)
  end

  test "filled sections keep the outline's order, so a part added later still comes before the Bible study" do
    note = meeting_notes(:head_midweek)
    note.revise!(parts_attributes: [ { title: "Second part" } ])

    _section, parts = note.reload.filled_sections.last
    assert_equal %w[ living_part congregation_bible_study ], parts.map(&:key)
  end

  test "an unknown kind is a validation error, not an ArgumentError" do
    note = MeetingNote.new(user: users(:spouse), kind: "assembly", week_of: Date.new(2026, 11, 16))

    assert_not note.valid?
    assert_includes note.errors[:kind], "is not included in the list"
  end

  test "requires week_of" do
    note = MeetingNote.new(user: users(:spouse), kind: "midweek")

    assert_not note.valid?
    assert_includes note.errors[:week_of], "can't be blank"
  end

  test "destroying the author destroys their notes, parts, part notes and gems" do
    assert_difference -> { MeetingNote.count } => -2, -> { MeetingNote::Part.count } => -8, -> { ActionText::RichText.count } => -2, -> { MeetingNote::Gem.count } => -2 do
      users(:head).destroy!
    end
  end

  test "database: a kind outside the list raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      MeetingNote.insert!({ user_id: users(:spouse).id, kind: "assembly", week_of: Date.new(2026, 11, 16) })
    end
  end

  # normalizes turns a Tuesday into Monday even through update_column, insert! and update_all with a
  # hash, so the Tuesday goes in as SQL to reach the check constraint.
  test "database: a Tuesday week_of raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { MeetingNote.where(id: meeting_notes(:head_midweek).id).update_all("week_of = DATE '2026-11-17'") }
  end

  test "database: a duplicate note for the same user, kind and week raises RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      MeetingNote.insert!({ user_id: users(:head).id, kind: "midweek", week_of: Date.new(2026, 11, 16) })
    end
  end

  test "database: two talk parts on one note raise RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      MeetingNote::Part.insert!({ meeting_note_id: meeting_notes(:head_midweek).id, key: "talk", position: 7 })
    end
  end

  test "database: two living parts on one note are allowed" do
    assert_difference -> { meeting_notes(:head_midweek).parts.count } do
      MeetingNote::Part.insert!({ meeting_note_id: meeting_notes(:head_midweek).id, key: "living_part", position: 7 })
    end
  end

  test "database: a note without a user raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { meeting_notes(:head_midweek).update_column(:user_id, nil) }
  end

  test "database: a note for a missing user raises InvalidForeignKey" do
    assert_raises(ActiveRecord::InvalidForeignKey) { meeting_notes(:head_midweek).update_column(:user_id, SecureRandom.uuid_v7) }
  end

  test "database: a note without an outline_version raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { meeting_notes(:head_midweek).update_column(:outline_version, nil) }
  end

  test "database: a part without a position raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { meeting_note_parts(:head_talk).update_column(:position, nil) }
  end

  test "database: deleting a note deletes its parts" do
    assert_difference -> { MeetingNote::Part.count }, -2 do
      MeetingNote.where(id: meeting_notes(:head_weekend).id).delete_all
    end
  end
end
