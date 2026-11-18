require "test_helper"

# Keep in Notes: the brief the page shows, kept as one of the person's own notes (docs/design/daily-brief.md, Keep in
# Notes, and print). Tuesday 17 November 2026, 9:00 AM in Hannah's zone.
class DailyBriefs::NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @user = users(:head)
    @user.update!(time_zone: "Central Time (US & Canada)")
    travel_to Time.utc(2026, 11, 17, 15)
    travel_to(3.days.ago) { DailyBrief::Plan.start(@user, starter: "husband_and_father") }
    @brief = DailyBrief.for(@user)
    daily_brief_writing(@brief, status: "written", result: { "thread" => "A thread" })
    sign_in identities(:head)
  end

  test "create keeps today's brief as the person's note and redirects to it" do
    assert_difference(-> { @user.personal_notes.count }, 1) { post household_daily_brief_note_path(household_id: @home) }

    note = @user.personal_notes.find_by!(title: "Daily brief · Tuesday, November 17")
    assert_redirected_to household_personal_note_path(household_id: @home, id: note)
    assert_equal "Kept in Notes.", flash[:notice]
    assert_includes note.body.to_plain_text, "A thread"
  end

  test "before today's is made it keeps the brief the page shows, the newest before today" do
    yesterday = DailyBrief.for(@user, on: Date.new(2026, 11, 16))
    @brief.destroy!

    post household_daily_brief_note_path(household_id: @home)

    note = @user.personal_notes.find_by!(title: "Daily brief · Monday, November 16")
    assert_redirected_to household_personal_note_path(household_id: @home, id: note)
    assert yesterday.reload
  end

  test "a child is refused" do
    sign_in identities(:eli)

    assert_no_difference(-> { PersonalNote.count }) { post household_daily_brief_note_path(household_id: @home) }

    assert_redirected_to household_root_path(household_id: @home)
  end

  test "with no brief nothing is kept" do
    @brief.destroy!

    assert_no_difference(-> { PersonalNote.count }) { post household_daily_brief_note_path(household_id: @home) }

    assert_redirected_to household_daily_brief_path(household_id: @home)
    assert_equal "There's no brief to keep yet.", flash[:alert]
  end
end
