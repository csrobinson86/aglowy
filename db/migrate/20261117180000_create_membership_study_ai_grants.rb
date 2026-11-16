class CreateMembershipStudyAiGrants < ActiveRecord::Migration[8.1]
  def change
    # A head's say-so for a child's personal study with AI, as a record: turning it off deletes it
    # (docs/design/personal-study.md, Children). The unique index is what create_or_find_by! relies on, so two heads
    # turning it on at once make one row; leaving the household or being deleted takes it with the membership.
    create_table :membership_study_ai_grants, id: :uuid do |t|
      t.references :membership, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.references :granted_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end
