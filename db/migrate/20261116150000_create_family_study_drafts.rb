class CreateFamilyStudyDrafts < ActiveRecord::Migration[8.1]
  def change
    # One AI request to draft a family study (docs/design/family-studies.md, FamilyStudy::Draft). The draft goes with
    # its chat, so the daily purge removes both. prompt and outline are encrypted, so prompt is text.
    create_table :family_study_drafts, id: :uuid do |t|
      t.references :household, null: false, foreign_key: true, type: :uuid, index: false
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :chat, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: { unique: true }
      t.text :prompt, null: false
      t.integer :length_minutes, null: false
      t.boolean :young_children, null: false, default: false
      t.string :status, null: false, default: "drafting"
      t.jsonb :outline
      t.jsonb :sources, null: false, default: []
      t.timestamps

      # The day's count (counted_today).
      t.index %i[ household_id created_at ]
      t.check_constraint "length_minutes IN (30, 45, 60)", name: "family_study_drafts_length_minutes_check"
      t.check_constraint "status IN ('drafting', 'drafted', 'off_topic', 'flagged', 'failed', 'stopped', 'discarded')",
                         name: "family_study_drafts_status_check"
    end
  end
end
