require "test_helper"

class MeetingNotes::SummariesControllerTest < ActionDispatch::IntegrationTest
  setup do
    households(:home).enable_meeting_helper(by: users(:head))
    @note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
  end

  test "shows marks and drawings for the right steps" do
    @note.mark("talk")
    @note.mark("closing_song")
    @note.draw("field_ministry", fixture_file_upload("photo.png", "image/png"))
    sign_in identities(:eli)

    get summary_path

    assert_response :success
    assert_select "body[data-color-mode=dark]"
    assert_select "main h1", "You listened all the way through!"
    assert_select "main", text: /Here's what you did today\./
    assert_select "main li", 8
    assert_select "main li#summary-talk", text: /Treasures\s*✓ Heard it/
    assert_select "main li#summary-closing_song", text: /Last song\s*✓ Sang it/
    assert_select "main li#summary-field_ministry" do
      assert_select "img[alt='Your drawing'][src='#{household_meeting_note_step_drawing_path(household_id: households(:home), meeting_note_id: @note, step_id: "field_ministry")}']"
    end
    assert_select "main li#summary-field_ministry", text: /✓/, count: 0
    assert_select "main img", 1
    assert_no_match "/rails/active_storage/", response.body
    assert_no_match(/missed|score|\d+ of \d+/i, response.body)
  end

  test "a step with neither shows only its title" do
    sign_in identities(:eli)

    get summary_path

    assert_select "main li#summary-spiritual_gems", text: /\A\s*Spiritual gems\s*\z/
    assert_select "main li#summary-spiritual_gems img", count: 0
  end

  test "Show my family until the note is shared, then Your family can see it now, and Finished goes Home" do
    sign_in identities(:eli)

    get summary_path

    assert_select "main form[action='#{household_meeting_note_sharing_path(household_id: households(:home), meeting_note_id: @note)}'][method=post]" do
      assert_select "input[type=hidden][name=return_to][value='#{summary_path}']"
      assert_select "button[type=submit]", text: "Show my family"
    end
    assert_select "main [role=status]", count: 0
    assert_select "main a[href='#{household_root_path(household_id: households(:home))}']", "Finished"

    @note.share_with(households(:home))
    get summary_path

    assert_select "main [role=status]", "Your family can see it now"
    assert_select "main button", text: "Show my family", count: 0
  end

  test "another person's note is 404" do
    sign_in identities(:eli)

    get household_meeting_note_summary_path(household_id: households(:home), meeting_note_id: meeting_notes(:head_midweek))

    assert_response :not_found
  end

  test "a head is 404" do
    sign_in identities(:head)

    get household_meeting_note_summary_path(household_id: households(:home), meeting_note_id: meeting_notes(:head_midweek))

    assert_response :not_found
  end

  private
    def summary_path
      household_meeting_note_summary_path(household_id: households(:home), meeting_note_id: @note)
    end
end
