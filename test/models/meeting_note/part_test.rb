require "test_helper"

class MeetingNote::PartTest < ActiveSupport::TestCase
  test "title, speaker and notes are stored encrypted" do
    part = meeting_note_parts(:head_public_talk)
    part.update!(title: "Find Refuge in Jehovah", speaker: "Daniel Okafor", notes: "<p>Psalm 91 as a hiding place</p>")

    raw = MeetingNote::Part.connection.select_one(MeetingNote::Part.where(id: part.id).select(:title, :speaker).to_sql)
    raw_notes = ActionText::RichText.connection.select_value(ActionText::RichText.where(record: part, name: "notes").select(:body).to_sql)

    assert_not_includes raw["title"], "Find Refuge"
    assert_not_includes raw["speaker"], "Okafor"
    assert_not_includes raw_notes, "hiding place"

    part.reload
    assert_equal "Find Refuge in Jehovah", part.title
    assert_equal "Daniel Okafor", part.speaker
    assert_includes part.notes.to_plain_text, "Psalm 91 as a hiding place"
  end

  test "fixture titles, speakers and notes read back decrypted" do
    assert_equal "Daniel Okafor", meeting_note_parts(:head_public_talk).speaker
    assert_includes meeting_note_parts(:head_congregation_bible_study).notes.to_plain_text, "prayer a habit"
  end

  test "repeats? follows the outline" do
    assert meeting_note_parts(:head_living_part).repeats?
    assert_not meeting_note_parts(:head_talk).repeats?
  end

  test "only a part whose outline asks for a speaker can have one" do
    part = meeting_note_parts(:head_talk)
    part.speaker = "Daniel Okafor"

    assert_not part.valid?
    assert_includes part.errors[:speaker], "isn't asked for in this part"
    assert meeting_note_parts(:head_public_talk).valid?
  end

  test "requires a position" do
    part = meeting_notes(:head_midweek).parts.new(key: "living_part")

    assert_not part.valid?
    assert_includes part.errors[:position], "can't be blank"
  end

  test "requires a note" do
    part = MeetingNote::Part.new(key: "talk", position: 1)

    assert_not part.valid?
    assert_includes part.errors[:meeting_note], "must exist"
  end
end
