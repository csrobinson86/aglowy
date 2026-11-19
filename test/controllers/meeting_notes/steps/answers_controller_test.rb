require "test_helper"

class MeetingNotes::Steps::AnswersControllerTest < ActionDispatch::IntegrationTest
  setup do
    households(:home).enable_meeting_helper(by: users(:head))
    @note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
  end

  test "a child writes her answer, and goes back to the step" do
    sign_in identities(:eli)
    get edit_answer_path

    assert_response :success
    assert_select "h1", text: "My answer for Bible study"
    assert_select "input[type=number][name='answer[paragraph]']"
    assert_select "textarea[name='answer[body]']"
    assert_select "button[type=submit]", text: "Save my answer"

    patch answer_path, params: { answer: { paragraph: "7", body: "Jehovah helps us when we are sad." } }

    assert_redirected_to household_meeting_note_step_path(household_id: households(:home), meeting_note_id: @note, id: "congregation_bible_study")
    assert_equal [ 7, "Jehovah helps us when we are sad." ], @note.reload.answer.values_at(:paragraph, :body)
  end

  test "a child changes her answer" do
    @note.write_answer(paragraph: 7, body: "Jehovah helps us when we are sad.")
    sign_in identities(:eli)
    get edit_answer_path

    assert_select "input[name='answer[paragraph]'][value='7']"
    assert_select "textarea[name='answer[body]']", text: "Jehovah helps us when we are sad."

    assert_no_difference -> { MeetingNote::Answer.count } do
      patch answer_path, params: { answer: { paragraph: "8", body: "Jesus was kind." } }
    end
    assert_redirected_to household_meeting_note_step_path(household_id: households(:home), meeting_note_id: @note, id: "congregation_bible_study")
    assert_equal [ 8, "Jesus was kind." ], @note.reload.answer.values_at(:paragraph, :body)
  end

  test "a blank answer is refused, with the error on its field" do
    sign_in identities(:eli)

    patch answer_path, params: { answer: { paragraph: "7", body: "" } }

    assert_response :unprocessable_content
    assert_select "textarea[name='answer[body]'][aria-invalid=true]"
    assert_select ".FormControl-inlineValidation", text: "What I'll say can't be blank"
    assert_nil @note.reload.answer
  end

  test "another step is 404" do
    sign_in identities(:eli)

    get edit_answer_path(step_id: "talk")

    assert_response :not_found
  end

  test "saving on another step is 404" do
    sign_in identities(:eli)

    patch answer_path(step_id: "talk"), params: { answer: { paragraph: "7", body: "Jesus was kind." } }

    assert_response :not_found
    assert_nil @note.reload.answer
  end

  test "an adult is 404" do
    sign_in identities(:spouse)
    note = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))

    get edit_answer_path(meeting_note_id: note)

    assert_response :not_found
  end

  test "an adult saving is 404" do
    sign_in identities(:spouse)
    note = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))

    patch answer_path(meeting_note_id: note), params: { answer: { paragraph: "7", body: "Jesus was kind." } }

    assert_response :not_found
    assert_nil note.reload.answer
  end

  test "another person's note is 404" do
    sign_in identities(:eli)

    patch answer_path(meeting_note_id: meeting_notes(:head_midweek)), params: { answer: { paragraph: "7", body: "Jesus was kind." } }

    assert_response :not_found
    assert_nil meeting_notes(:head_midweek).reload.answer
  end

  test "a child with the helper off is 404, and her answer stays" do
    @note.write_answer(paragraph: 7, body: "Jehovah helps us when we are sad.")
    households(:home).disable_meeting_helper
    sign_in identities(:eli)

    get edit_answer_path

    assert_response :not_found
    assert_equal 7, @note.reload.answer.paragraph
  end

  private
    def edit_answer_path(meeting_note_id: @note, step_id: "congregation_bible_study")
      edit_household_meeting_note_step_answer_path(household_id: households(:home), meeting_note_id:, step_id:)
    end

    def answer_path(meeting_note_id: @note, step_id: "congregation_bible_study")
      household_meeting_note_step_answer_path(household_id: households(:home), meeting_note_id:, step_id:)
    end
end
