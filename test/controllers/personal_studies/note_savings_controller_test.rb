require "test_helper"

# Save to note on an answer card (docs/design/personal-study.md, Save to note).
class PersonalStudies::NoteSavingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @study = personal_studies(:head_suffering)
  end

  test "saves the answer to the study's note and streams the saved footer and the note panel" do
    question = answered_question(@study)
    sign_in identities(:head)

    assert_difference -> { PersonalNote.count } => 1, -> { PersonalStudy::Question::NoteSaving.count } => 1 do
      save_to_note question
    end

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    note = @study.reload.note
    assert_select "turbo-stream[action=replace][target=note_saving_personal_study_question_#{question.id}] template" do
      assert_select "*", text: /Saved to note/
      assert_select "a[href='#{household_personal_note_path(household_id: @home, id: note)}']", text: "Open note"
      assert_select "button", false
    end
    assert_select "turbo-stream[action=replace][target=note_personal_study_#{@study.id}] template" do
      assert_select "a[href=?]", household_personal_note_path(household_id: @home, id: note), text: note.title
    end
    assert_includes note.body.to_plain_text, "Jehovah never causes suffering."
    assert_equal [ Bible::Reference.find("59:1:13") ], note.body.body.attachables
  end

  test "a second save adds nothing" do
    question = answered_question(@study)
    sign_in identities(:head)
    save_to_note question

    assert_no_difference -> { PersonalNote.count } do
      assert_no_changes -> { @study.note.reload.updated_at } do
        save_to_note question
      end
    end

    assert_response :success
    assert_select "turbo-stream[target=note_saving_personal_study_question_#{question.id}] a", text: "Open note"
  end

  test "another person's question: 404" do
    question = answered_question(personal_studies(:spouse_ransom))
    sign_in identities(:head)

    save_to_note question, study: personal_studies(:spouse_ransom)

    assert_response :not_found
    assert_nil personal_studies(:spouse_ransom).reload.note
  end

  test "another person's question under my own study: 404" do
    question = answered_question(personal_studies(:spouse_ransom))
    sign_in identities(:head)

    save_to_note question

    assert_response :not_found
  end

  test "not answered: 422" do
    question = personal_study_question(@study, status: "stopped")
    sign_in identities(:head)

    save_to_note question

    assert_response :unprocessable_content
    assert_nil @study.reload.note
  end

  test "a non-member of the household: 404" do
    question = answered_question(@study)
    sign_in identities(:outsider)

    save_to_note question

    assert_response :not_found
  end

  private
    def answered_question(study)
      personal_study_question(study, status: "answered", answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Jehovah never causes suffering. Read James 1:13." ], "next_questions" => [] },
        sources: [ { "url" => "https://www.jw.org/en/bible-teachings/questions/why-does-god-allow-suffering/", "title" => "Why Does God Allow Suffering?" } ])
    end

    def save_to_note(question, study: @study)
      post household_personal_study_question_note_saving_path(household_id: @home, personal_study_id: study, question_id: question), as: :turbo_stream
    end
end
