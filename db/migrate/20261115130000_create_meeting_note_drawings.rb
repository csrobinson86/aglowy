class CreateMeetingNoteDrawings < ActiveRecord::Migration[8.1]
  def change
    # A child's drawing for one step of a meeting helper note; the PNG is its Active Storage image
    # (docs/design/meeting-helper.md, Models). The unique index keeps one drawing per step and serves lookups by note.
    create_table :meeting_note_drawings, id: :uuid do |t|
      t.references :meeting_note, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :step, null: false
      t.timestamps
      t.index %i[ meeting_note_id step ], unique: true
    end
  end
end
