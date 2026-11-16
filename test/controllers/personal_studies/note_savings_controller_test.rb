require "test_helper"

# Save to notes on an answer card (docs/design/personal-study.md, Save to notes).
class PersonalStudies::NoteSavingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @study = personal_studies(:head_suffering)
  end

  test "saves" do
    question = answered_question(@study)
    sign_in identities(:head)

    save_to_notes question

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_select "turbo-stream[action=replace][target=notes_personal_study_#{@study.id}]" do
      assert_select "template lexxy-editor[name='personal_study[notes]']"
    end
    assert_includes @study.reload.notes.to_plain_text, "Jehovah never causes suffering."
    assert_equal [ Bible::Reference.find("59:1:13") ], @study.notes.body.attachables
  end

  test "another person's question: 404" do
    question = answered_question(personal_studies(:spouse_ransom))
    sign_in identities(:head)

    save_to_notes question, study: personal_studies(:spouse_ransom)

    assert_response :not_found
    assert_nil personal_studies(:spouse_ransom).reload.notes
  end

  test "another person's question under my own study: 404" do
    question = answered_question(personal_studies(:spouse_ransom))
    sign_in identities(:head)

    save_to_notes question

    assert_response :not_found
  end

  test "not answered: 422" do
    question = personal_study_question(@study, status: "stopped")
    sign_in identities(:head)

    save_to_notes question

    assert_response :unprocessable_content
    assert_nil @study.reload.notes
  end

  test "a non-member of the household: 404" do
    question = answered_question(@study)
    sign_in identities(:outsider)

    save_to_notes question

    assert_response :not_found
  end

  private
    def answered_question(study)
      personal_study_question(study, status: "answered", answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Jehovah never causes suffering. Read James 1:13." ], "next_questions" => [] },
        sources: [ { "url" => "https://www.jw.org/en/bible-teachings/questions/why-does-god-allow-suffering/", "title" => "Why Does God Allow Suffering?" } ])
    end

    def save_to_notes(question, study: @study)
      post household_personal_study_question_note_saving_path(household_id: @home, personal_study_id: study, question_id: question), as: :turbo_stream
    end
end
