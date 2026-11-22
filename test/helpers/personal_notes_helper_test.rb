require "test_helper"

class PersonalNotesHelperTest < ActionView::TestCase
  setup { Current.household = households(:home) }

  test "note_row_line is the collection, the day the note was edited and its preview" do
    note = personal_notes(:head_daniel)
    note.update!(body: "<p>Head of gold, <b>chest</b> of silver.</p>")

    assert_equal "Quick references · today · Head of gold, chest of silver.", note_row_line(note)
  end

  test "note_row_line leaves out a missing collection and an empty body" do
    assert_equal "today", note_row_line(personal_notes(:head_family_worship).tap(&:touch))
  end

  test "note_row_line shows an earlier day as its month and day, with the year when it isn't this year, in the household's zone" do
    note = personal_notes(:head_family_worship)

    travel_to Time.zone.local(2026, 11, 22, 12) do
      note.update_column(:updated_at, Time.zone.local(2026, 11, 10, 12))
      assert_equal "Nov 10", note_row_line(note)

      note.update_column(:updated_at, Time.zone.local(2025, 11, 10, 12))
      assert_equal "Nov 10, 2025", note_row_line(note)

      households(:home).update!(time_zone: "Tokyo")
      note.update_column(:updated_at, Time.utc(2026, 11, 21, 16))
      assert_equal "today", note_row_line(note)
    end
  end
end
