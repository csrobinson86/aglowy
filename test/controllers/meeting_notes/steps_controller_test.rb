require "test_helper"

class MeetingNotes::StepsControllerTest < ActionDispatch::IntegrationTest
  setup do
    households(:home).enable_meeting_helper(by: users(:head))
    @note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
  end

  test "each midweek step renders its prompt" do
    sign_in identities(:eli)

    MeetingNote::HelperSteps.for("midweek").each.with_index(1) do |step, position|
      get step_path(step.key)

      assert_response :success
      assert_select "body[data-color-mode=dark]"
      assert_select "main h1", step.prompt
      assert_select "main", text: /#{Regexp.escape(step.title)}/
      assert_select "main .meeting-helper__icon svg[aria-hidden=true]"
      assert_select "header", text: /Midweek meeting/
      assert_select "header .sr-only", "Part #{position} of 8: #{step.title}"
    end
  end

  test "Back and Next go from step to step" do
    sign_in identities(:eli)

    get step_path("talk")

    assert_select "main a[href='#{step_path("opening_song")}']", "Back"
    assert_select "main a[href='#{step_path("spiritual_gems")}']", "Next"
  end

  test "Back from the first step links to Home" do
    sign_in identities(:eli)

    get step_path("opening_song")

    assert_select "main a[href='#{household_root_path(household_id: households(:home))}']", "Back"
    assert_select "main a[href='#{step_path("talk")}']", "Next"
  end

  test "Finish on the last step goes to the summary" do
    sign_in identities(:eli)

    get step_path("closing_song")

    assert_select "main a[href='#{step_path("congregation_bible_study")}']", "Back"
    assert_select "main a[href='#{household_meeting_note_summary_path(household_id: households(:home), meeting_note_id: @note)}']", "Finish"
    assert_select "main a", text: "Next", count: 0
  end

  test "the mark button, unmarked and marked, and a marked step's dot is filled" do
    sign_in identities(:eli)

    get step_path("field_ministry")

    assert_select "main ##{dom_id(@note, :mark)} form[method=post] button[aria-pressed=false]", text: "I watched!"
    assert_select "header .meeting-helper__dot--marked", count: 0

    @note.mark("opening_song")
    @note.mark("field_ministry")
    get step_path("field_ministry")

    assert_select "main ##{dom_id(@note, :mark)} input[name=_method][value=delete]"
    assert_select "main ##{dom_id(@note, :mark)} button[aria-pressed=true]", text: "✓ Watched it"
    assert_select "main button[autofocus]", count: 0
    assert_select "header .meeting-helper__dot--marked", count: 2
  end

  test "Draw it, or My drawing once there is one, and a drawn step's dot is filled" do
    sign_in identities(:eli)

    get step_path("talk")

    assert_select "main a[href='#{edit_household_meeting_note_step_drawing_path(household_id: households(:home), meeting_note_id: @note, step_id: "talk")}']", "Draw it"
    assert_select "header .meeting-helper__dot--marked", count: 0

    @note.draw("talk", fixture_file_upload("photo.png", "image/png"))
    get step_path("talk")

    assert_select "main a", text: "My drawing"
    assert_select "main a", text: "Draw it", count: 0
    assert_select "header .meeting-helper__dot--marked", count: 1
  end

  test "an unknown step key is 404" do
    sign_in identities(:eli)

    get step_path("public_talk") # a weekend step, not in a midweek note

    assert_response :not_found
  end

  test "another person's note is 404" do
    sign_in identities(:eli)

    get household_meeting_note_step_path(household_id: households(:home), meeting_note_id: meeting_notes(:head_midweek), id: "opening_song")

    assert_response :not_found
  end

  test "a head is 404" do
    sign_in identities(:head)

    get household_meeting_note_step_path(household_id: households(:home), meeting_note_id: meeting_notes(:head_midweek), id: "opening_song")

    assert_response :not_found
  end

  test "a child with the helper off is 404" do
    households(:home).disable_meeting_helper
    sign_in identities(:eli)

    get step_path("opening_song")

    assert_response :not_found
  end

  test "a household you're not in is 404" do
    households(:other).enable_meeting_helper(by: users(:outsider))
    sign_in identities(:eli)

    get household_meeting_note_step_path(household_id: households(:other), meeting_note_id: @note, id: "opening_song")

    assert_response :not_found
  end

  private
    def step_path(key)
      household_meeting_note_step_path(household_id: households(:home), meeting_note_id: @note, id: key)
    end
end
