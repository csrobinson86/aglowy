require "test_helper"

class MeetingNote::MarkTest < ActiveSupport::TestCase
  test "a step of the note's kind is valid" do
    assert meeting_notes(:head_weekend).marks.new(step: "public_talk").valid?
  end

  test "database: deleting a note deletes its marks" do
    meeting_notes(:head_weekend).mark("public_talk")

    assert_difference -> { MeetingNote::Mark.count }, -1 do
      MeetingNote.where(id: meeting_notes(:head_weekend).id).delete_all
    end
  end

  test "database: a mark without a step raises NotNullViolation" do
    mark = meeting_notes(:head_midweek).mark("talk")

    assert_raises(ActiveRecord::NotNullViolation) { mark.update_column(:step, nil) }
  end

  test "database: a mark without a note raises NotNullViolation" do
    mark = meeting_notes(:head_midweek).mark("talk")

    assert_raises(ActiveRecord::NotNullViolation) { mark.update_column(:meeting_note_id, nil) }
  end

  test "database: a mark for a missing note raises InvalidForeignKey" do
    mark = meeting_notes(:head_midweek).mark("talk")

    assert_raises(ActiveRecord::InvalidForeignKey) { mark.update_column(:meeting_note_id, SecureRandom.uuid_v7) }
  end

  test "database: a mark without a created_at raises NotNullViolation" do
    mark = meeting_notes(:head_midweek).mark("talk")

    assert_raises(ActiveRecord::NotNullViolation) { mark.update_column(:created_at, nil) }
  end

  test "database: the unique index rejects a duplicate" do
    meeting_notes(:head_midweek).mark("talk")

    assert_raises ActiveRecord::RecordNotUnique do
      MeetingNote::Mark.insert!({ meeting_note_id: meeting_notes(:head_midweek).id, step: "talk" })
    end
  end
end
