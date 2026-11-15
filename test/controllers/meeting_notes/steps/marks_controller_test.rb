require "test_helper"

class MeetingNotes::Steps::MarksControllerTest < ActionDispatch::IntegrationTest
  setup do
    households(:home).enable_meeting_helper(by: users(:head))
    @note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
  end

  test "a child marks and unmarks" do
    sign_in identities(:eli)

    post mark_path("talk")

    assert_redirected_to household_meeting_note_step_path(household_id: households(:home), meeting_note_id: @note, id: "talk")
    assert @note.marked?("talk")

    delete mark_path("talk")

    assert_redirected_to household_meeting_note_step_path(household_id: households(:home), meeting_note_id: @note, id: "talk")
    assert_not @note.reload.marked?("talk")
  end

  test "the Turbo Stream replaces the button" do
    sign_in identities(:eli)

    post mark_path("talk"), as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=replace][target=#{dom_id(@note, :mark)}]" do
      assert_select "template form[action='#{mark_path("talk")}'] input[name=_method][value=delete]"
      assert_select "template button[aria-pressed=true][autofocus]", text: "✓ Heard it"
    end

    delete mark_path("talk"), as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=replace][target=#{dom_id(@note, :mark)}]" do
      assert_select "template form[action='#{mark_path("talk")}'] input[name=_method]", count: 0
      assert_select "template button[aria-pressed=false][autofocus] svg[aria-hidden=true]"
      assert_select "template button", text: "I heard it!"
    end
  end

  test "marking twice keeps one mark" do
    sign_in identities(:eli)

    assert_difference -> { @note.marks.count }, 1 do
      2.times { post mark_path("opening_song"), as: :turbo_stream }
    end
    assert_select "button[aria-pressed=true]", text: "✓ Sang it"
  end

  test "a step from the other kind is 404" do
    sign_in identities(:eli)

    post mark_path("public_talk")

    assert_response :not_found
  end

  test "another person's note is 404" do
    sign_in identities(:eli)

    post household_meeting_note_step_mark_path(household_id: households(:home), meeting_note_id: meeting_notes(:head_midweek), step_id: "talk")

    assert_response :not_found
    assert_empty meeting_notes(:head_midweek).marks
  end

  test "a head is 404" do
    sign_in identities(:head)

    post household_meeting_note_step_mark_path(household_id: households(:home), meeting_note_id: meeting_notes(:head_midweek), step_id: "talk")

    assert_response :not_found
    assert_empty meeting_notes(:head_midweek).marks
  end

  test "a child with the helper off is 404, and their mark stays" do
    @note.mark("talk")
    households(:home).disable_meeting_helper
    sign_in identities(:eli)

    delete mark_path("talk")

    assert_response :not_found
    assert @note.marked?("talk")
  end

  private
    def mark_path(key)
      household_meeting_note_step_mark_path(household_id: households(:home), meeting_note_id: @note, step_id: key)
    end
end
