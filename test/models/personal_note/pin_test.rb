require "test_helper"

class PersonalNote::PinTest < ActiveSupport::TestCase
  test "pin_to_top pins a note once, however often it's pinned" do
    note = personal_notes(:head_daniel)

    assert_difference -> { PersonalNote::Pin.count } do
      note.pin_to_top
      note.pin_to_top
    end
    assert note.pinned?
  end

  test "unpin takes the pin away" do
    note = personal_notes(:head_daniel)
    note.pin_to_top

    note.unpin

    assert_not note.pinned?
    assert_not note.reload.pinned?
  end

  test "pinned lists pinned notes, newest pin first; unpinned the rest" do
    travel_to(2.days.ago) { personal_notes(:head_daniel).pin_to_top }
    personal_notes(:head_return_visit).pin_to_top

    assert_equal [ personal_notes(:head_return_visit), personal_notes(:head_daniel) ], users(:head).personal_notes.pinned.to_a
    assert_equal [ personal_notes(:head_family_worship) ], users(:head).personal_notes.unpinned.to_a
  end

  test "deleting the note deletes the pin" do
    personal_notes(:head_daniel).pin_to_top

    assert_difference -> { PersonalNote::Pin.count }, -1 do
      PersonalNote.where(id: personal_notes(:head_daniel)).delete_all
    end
  end

  test "the database refuses a second pin for one note" do
    personal_notes(:head_daniel).pin_to_top

    assert_raises ActiveRecord::RecordNotUnique do
      PersonalNote::Pin.insert!({ personal_note_id: personal_notes(:head_daniel).id })
    end
  end
end
