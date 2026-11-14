class CreateMeetingNoteSharings < ActiveRecord::Migration[8.1]
  def change
    # Sharing is a record, not a flag: stopping deletes it (docs/design/meeting-notes.md, MeetingNote::Sharing).
    create_table :meeting_note_sharings, id: :uuid do |t|
      t.references :meeting_note, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :household, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :created_at, null: false
    end

    # Leads with meeting_note_id, so it also serves a note's own sharings.
    add_index :meeting_note_sharings, %i[ meeting_note_id household_id ], unique: true, name: "index_meeting_note_sharings_on_note_and_household"
  end
end
