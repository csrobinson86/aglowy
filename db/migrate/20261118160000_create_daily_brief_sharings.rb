class CreateDailyBriefSharings < ActiveRecord::Migration[8.1]
  # Today's thought shared with a household: a record, not a flag, so stopping deletes it
  # (docs/design/daily-brief.md, For the children, and sharing; like meeting_part_sharings).
  def change
    create_table :daily_brief_sharings, id: :uuid do |t|
      t.references :daily_brief, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :household, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :created_at, null: false
    end

    # Leads with daily_brief_id, so it also serves a brief's own sharings.
    add_index :daily_brief_sharings, %i[ daily_brief_id household_id ], unique: true, name: "index_daily_brief_sharings_on_brief_and_household"
  end
end
