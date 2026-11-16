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

  test "notes with a scripture attachment are valid" do
    part = meeting_note_parts(:head_talk)
    part.notes = "<p>Let go of anger. #{scripture_attachment("19:37:8-9")}</p>"

    assert part.valid?
  end

  test "notes with an attachment for another record are invalid" do
    part = meeting_note_parts(:head_talk)
    part.notes = "<p>#{foreign_attachment(users(:spouse))}</p>"

    assert_not part.valid?
    assert_equal [ "Notes can only link scriptures" ], part.errors.full_messages_for(:notes)
  end

  test "notes with a remote image attachment are invalid" do
    part = meeting_note_parts(:head_talk)
    part.notes = "<p>#{remote_image_attachment}</p>"

    assert_not part.valid?
    assert_equal [ "Notes can only link scriptures" ], part.errors.full_messages_for(:notes)
  end

  test "notes with a plain image are invalid, and the image leaves the unsaved notes" do
    part = meeting_note_parts(:head_talk)
    part.notes = "<p>Read #{scripture_attachment("40:24:14")}</p>#{image_tag_html}"

    assert_not part.valid?
    assert_equal [ "Notes can only link scriptures" ], part.errors.full_messages_for(:notes)
    assert_empty part.notes.body.fragment.find_all("img")
    assert_equal [ Bible::Reference.find("40:24:14") ], part.notes.body.attachables
  end

  test "a refused attachment leaves the unsaved notes, so the form shows what's left" do
    part = meeting_note_parts(:head_talk)
    part.notes = "<p>Kept #{scripture_attachment("40:24:14")} #{foreign_attachment(users(:spouse))}#{remote_image_attachment}</p>"

    assert_not part.valid?
    assert_equal [ Bible::Reference.find("40:24:14") ], part.notes.body.attachables
    assert_equal "Kept Matthew 24:14", part.notes.to_plain_text.strip
    assert_includes MeetingNote::Part.find(part.id).notes.to_plain_text, "Jehovah promises", "nothing is saved"
  end

  test "link_scriptures links the notes and keeps the other formatting" do
    part = meeting_note_parts(:head_talk)
    part.notes = "<p><strong>Keep on the watch</strong>: matt 24:14</p><ul><li>Ps 37:8-9</li></ul>"

    part.link_scriptures

    assert_equal %w[ 40:24:14 19:37:8-9 ].map { Bible::Reference.find(it) }, part.notes.body.attachables
    assert_equal [ "Keep on the watch" ], part.notes.body.fragment.find_all("strong").map(&:text)
    assert_equal 1, part.notes.body.fragment.find_all("ul li action-text-attachment").size
    assert part.valid?
  end
end
