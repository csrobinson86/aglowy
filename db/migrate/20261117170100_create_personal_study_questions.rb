class CreatePersonalStudyQuestions < ActiveRecord::Migration[8.1]
  def change
    # One question in a personal study and its checked answer (docs/design/personal-study.md,
    # PersonalStudy::Question). prompt and answer are encrypted, so their lengths are checked in the model.
    create_table :personal_study_questions, id: :uuid do |t|
      t.references :personal_study, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.text :prompt, null: false
      t.boolean :young_reader, null: false, default: false
      t.string :status, null: false, default: "asking"
      t.jsonb :answer
      t.jsonb :sources, null: false, default: []
      t.timestamps

      t.index %i[ personal_study_id created_at ], name: "index_personal_study_questions_on_study_and_created_at"
      t.check_constraint "status IN ('asking', 'answered', 'off_topic', 'flagged', 'failed', 'stopped')", name: "personal_study_questions_status_check"
    end
  end
end
