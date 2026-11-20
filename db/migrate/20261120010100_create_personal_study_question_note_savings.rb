class CreatePersonalStudyQuestionNoteSavings < ActiveRecord::Migration[8.1]
  # An answer saved to its study's note, as a record (docs/design/personal-study.md, PersonalStudy::Question::NoteSaving).
  # One per answer; it goes with the answer or the note, so deleting the note lets each answer be saved again.
  def change
    create_table :personal_study_question_note_savings, id: :uuid do |t|
      t.references :question, type: :uuid, null: false, foreign_key: { to_table: :personal_study_questions, on_delete: :cascade }, index: { unique: true }
      t.references :personal_note, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :created_at, null: false
    end
  end
end
