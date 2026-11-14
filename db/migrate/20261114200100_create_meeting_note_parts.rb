class CreateMeetingNoteParts < ActiveRecord::Migration[8.1]
  def change
    create_table :meeting_note_parts, id: :uuid do |t|
      t.references :meeting_note, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :key, null: false
      t.string :title
      t.string :speaker
      t.integer :position, null: false

      t.timestamps
    end

    # Only Living as Christians parts repeat; every other part appears once per note.
    add_index :meeting_note_parts, [ :meeting_note_id, :key ], unique: true, where: "key <> 'living_part'", name: "index_meeting_note_parts_on_note_and_key_once"
  end
end
