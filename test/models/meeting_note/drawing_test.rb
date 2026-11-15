require "test_helper"

class MeetingNote::DrawingTest < ActiveSupport::TestCase
  test "a PNG under 2 MB is valid" do
    assert drawing(file_fixture("photo.png").read).valid?
  end

  test "a JPEG is invalid" do
    drawing = drawing(file_fixture("drawing.jpg").read)

    assert_not drawing.valid?
    assert_equal [ "must be a PNG" ], drawing.errors[:image]
  end

  test "a PNG over 2 MB is invalid" do
    drawing = drawing(file_fixture("photo.png").read + ("\0" * 2.megabytes))

    assert_not drawing.valid?
    assert_equal [ "must be 2 MB or smaller" ], drawing.errors[:image]
  end

  test "a drawing without an image is invalid" do
    drawing = meeting_notes(:head_midweek).drawings.new(step: "talk")

    assert_not drawing.valid?
    assert_equal [ "can't be blank" ], drawing.errors[:image]
  end

  test "a step from the other kind is invalid" do
    drawing = drawing(file_fixture("photo.png").read, step: "public_talk")

    assert_not drawing.valid?
    assert_equal [ "isn't a step of this meeting" ], drawing.errors[:step]
  end

  test "destroying the note purges its drawings' images" do
    drawing(file_fixture("photo.png").read).save!

    assert_difference -> { ActiveStorage::Attachment.count }, -1 do
      meeting_notes(:head_midweek).destroy
    end
    assert_empty MeetingNote::Drawing.where(meeting_note_id: meeting_notes(:head_midweek).id)
  end

  test "database: deleting a note deletes its drawings" do
    drawing(file_fixture("photo.png").read).save!

    assert_difference -> { MeetingNote::Drawing.count }, -1 do
      MeetingNote.where(id: meeting_notes(:head_midweek).id).delete_all
    end
  end

  test "database: a drawing without a step raises NotNullViolation" do
    drawing = drawing(file_fixture("photo.png").read).tap(&:save!)

    assert_raises(ActiveRecord::NotNullViolation) { drawing.update_column(:step, nil) }
  end

  test "database: a drawing without a note raises NotNullViolation" do
    drawing = drawing(file_fixture("photo.png").read).tap(&:save!)

    assert_raises(ActiveRecord::NotNullViolation) { drawing.update_column(:meeting_note_id, nil) }
  end

  test "database: a drawing for a missing note raises InvalidForeignKey" do
    drawing = drawing(file_fixture("photo.png").read).tap(&:save!)

    assert_raises(ActiveRecord::InvalidForeignKey) { drawing.update_column(:meeting_note_id, SecureRandom.uuid_v7) }
  end

  test "database: the unique index rejects a second drawing for the step" do
    drawing(file_fixture("photo.png").read).save!

    assert_raises ActiveRecord::RecordNotUnique do
      MeetingNote::Drawing.insert!({ meeting_note_id: meeting_notes(:head_midweek).id, step: "talk" })
    end
  end

  private
    def drawing(bytes, step: "talk")
      meeting_notes(:head_midweek).drawings.new(step: step).tap do
        it.image.attach(io: StringIO.new(bytes), filename: "drawing.png")
      end
    end
end
