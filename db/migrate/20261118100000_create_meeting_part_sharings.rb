class CreateMeetingPartSharings < ActiveRecord::Migration[8.1]
  # A part shared, read-only, with a household: a record, not a flag, so stopping deletes it
  # (docs/design/meeting-parts.md, MeetingPart; like meeting_note_sharings).
  def change
    create_table :meeting_part_sharings, id: :uuid do |t|
      t.references :meeting_part, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :household, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :created_at, null: false
    end

    # Leads with meeting_part_id, so it also serves a part's own sharings.
    add_index :meeting_part_sharings, %i[ meeting_part_id household_id ], unique: true, name: "index_meeting_part_sharings_on_part_and_household"
  end
end
