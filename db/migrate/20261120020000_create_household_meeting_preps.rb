class CreateHouseholdMeetingPreps < ActiveRecord::Migration[8.1]
  def change
    # Get ready's switch is a record, like the meeting helper's: turning it off deletes it (docs/design/meeting-prep.md,
    # Models). The unique index is what create_or_find_by! relies on, so two adults turning it on at once make one row.
    create_table :household_meeting_preps, id: :uuid do |t|
      t.references :household, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.references :enabled_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end
