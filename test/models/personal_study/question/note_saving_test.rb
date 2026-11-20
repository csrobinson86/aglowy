require "test_helper"

# That an answer is in its study's note (docs/design/personal-study.md, PersonalStudy::Question::NoteSaving).
class PersonalStudy::Question::NoteSavingTest < ActiveSupport::TestCase
  test "database: an answer is saved to the note once" do
    question = personal_study_question(status: "answered", answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => [ "Jehovah never causes suffering." ], "next_questions" => [] })
    note = question.save_to_note

    assert_raises(ActiveRecord::RecordNotUnique) do
      PersonalStudy::Question::NoteSaving.insert!({ question_id: question.id, personal_note_id: note.id })
    end
  end
end
