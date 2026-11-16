class CreateAiUses < ActiveRecord::Migration[8.1]
  def change
    # The ledger a per-person daily limit counts (docs/design/personal-study.md, PersonalStudy::Question). Deleting a
    # question keeps its use, so deleting a study can't give questions back; the daily purge removes it after 2 days.
    create_table :ai_uses, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false
      t.string :purpose, null: false
      t.references :question, foreign_key: { to_table: :personal_study_questions, on_delete: :nullify }, type: :uuid, index: { unique: true }
      t.datetime :created_at, null: false

      t.index %i[ user_id purpose created_at ]
      t.index :created_at
      t.check_constraint "purpose IN ('family_study_draft', 'personal_study')", name: "ai_uses_purpose_check"
    end
  end
end
