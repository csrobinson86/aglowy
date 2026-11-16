require "test_helper"

class TaggableTest < ActiveSupport::TestCase
  test "tag_with reuses the person's tag when it's typed differently" do
    assert_no_difference -> { Tag.count } do
      meeting_notes(:head_weekend).tag_with("#Ministry", by: users(:head))
    end

    assert_equal [ tags(:head_ministry) ], meeting_notes(:head_weekend).tags.to_a
  end

  test "tag_with twice leaves one tagging" do
    assert_no_difference -> { Tagging.count } do
      meeting_notes(:head_midweek).tag_with("ministry", by: users(:head))
    end
  end

  test "tag_with on someone else's note raises and leaves no new tag behind" do
    assert_no_difference -> { Tag.count } do
      assert_raises(ActiveRecord::RecordInvalid) { meeting_notes(:head_midweek).tag_with("talk prep", by: users(:spouse)) }
    end
  end

  test "a refused tag_with rescued inside the caller's transaction still leaves no new tag behind" do
    assert_no_difference -> { Tag.count } do
      ActiveRecord::Base.transaction do
        assert_raises(ActiveRecord::RecordInvalid) { meeting_notes(:head_midweek).tag_with("talk prep", by: users(:spouse)) }
      end
    end
  end

  test "untag removes it from the note and keeps the tag" do
    note = meeting_notes(:head_midweek)
    note.tags.load

    note.untag(tags(:head_ministry))

    assert_empty note.tags
    assert Tag.exists?(tags(:head_ministry).id)
  end

  test "tagged_with finds the person's notes and goals with that tag" do
    note = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    note.tag_with("ministry", by: users(:spouse))
    goals(:spouse_bible_reading).tag_with("ministry", by: users(:spouse))

    assert_equal [ note ], MeetingNote.tagged_with(tags(:spouse_ministry)).to_a
    assert_equal [ goals(:spouse_bible_reading) ], Goal.tagged_with(tags(:spouse_ministry)).to_a
  end

  test "tags_for is the owner's tags, and empty for another member of a household the note is shared with" do
    note = meeting_notes(:head_midweek)
    note.share_with(households(:home))

    assert_equal [ tags(:head_ministry) ], note.tags_for(users(:head), membership: memberships(:head_in_home)).to_a
    assert_empty note.tags_for(users(:spouse), membership: memberships(:spouse_in_home))
  end

  test "deleting a tag removes its taggings" do
    assert_difference -> { Tagging.count } => -1 do
      tags(:head_ministry).destroy!
    end

    assert_empty meeting_notes(:head_midweek).tags
  end
end
