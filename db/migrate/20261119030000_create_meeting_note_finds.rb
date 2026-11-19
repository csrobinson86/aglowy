class CreateMeetingNoteFinds < ActiveRecord::Migration[8.1]
  def change
    # The child found the right card in a round of the listening game (docs/design/listening-game.md,
    # MeetingNote::Find). The label and kind are copied from the card, so the note reads the same after the game is
    # purged or changed (Trap 5). The unique index is what create_or_find_by! relies on, so two taps make one find
    # (Trap 6); it also serves lookups by note.
    create_table :meeting_note_finds, id: :uuid do |t|
      t.references :meeting_note, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :step, null: false
      t.integer :position, limit: 2, null: false
      t.string :label, null: false
      t.string :kind, null: false
      t.datetime :created_at, null: false
      t.index %i[ meeting_note_id step position ], unique: true, name: "index_meeting_note_finds_on_note_step_position"
    end
  end
end
