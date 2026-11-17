require "test_helper"

# Save as a note on an answer card (docs/design/notes.md, Save an AI answer as a note).
class PersonalStudies::PersonalNotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    @study = personal_studies(:head_suffering)
  end

  test "creates and redirects" do
    question = answered_question(@study)
    sign_in identities(:head)

    assert_difference -> { users(:head).personal_notes.count } do
      save_as_note question
    end

    note = users(:head).personal_notes.order(:created_at).last
    assert_redirected_to household_personal_note_path(household_id: @home, id: note)
    assert_equal "Why does Jehovah allow suffering?", note.title
    assert_includes note.body.to_plain_text, "Jehovah never causes suffering."
    assert_equal [ Bible::Reference.find("59:1:13") ], note.body.body.attachables
  end

  test "another person's question: 404" do
    question = answered_question(personal_studies(:spouse_ransom))
    sign_in identities(:head)

    assert_no_difference -> { PersonalNote.count } do
      save_as_note question, study: personal_studies(:spouse_ransom)
    end

    assert_response :not_found
  end

  test "another person's question under my own study: 404" do
    question = answered_question(personal_studies(:spouse_ransom))
    sign_in identities(:head)

    save_as_note question

    assert_response :not_found
  end

  test "not answered: 422" do
    question = personal_study_question(@study, status: "stopped")
    sign_in identities(:head)

    assert_no_difference -> { PersonalNote.count } do
      save_as_note question
    end

    assert_response :unprocessable_content
  end

  test "a non-member of the household: 404" do
    question = answered_question(@study)
    sign_in identities(:outsider)

    save_as_note question

    assert_response :not_found
  end

  private
    def answered_question(study)
      personal_study_question(study, status: "answered", answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Jehovah never causes suffering. Read James 1:13." ], "next_questions" => [] },
        sources: [ { "url" => "https://www.jw.org/en/bible-teachings/questions/why-does-god-allow-suffering/", "title" => "Why Does God Allow Suffering?" } ])
    end

    def save_as_note(question, study: @study)
      post household_personal_study_question_personal_note_path(household_id: @home, personal_study_id: study, question_id: question)
    end
end
