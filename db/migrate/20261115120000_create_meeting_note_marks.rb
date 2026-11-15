class CreateMeetingNoteMarks < ActiveRecord::Migration[8.1]
  def change
    # "I heard it!" for one step of a meeting helper note (docs/design/meeting-helper.md, Models). The unique index
    # is what create_or_find_by! relies on, so a double tap makes one mark; it also serves lookups by note.
    create_table :meeting_note_marks, id: :uuid do |t|
      t.references :meeting_note, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :step, null: false
      t.datetime :created_at, null: false
      t.index %i[ meeting_note_id step ], unique: true
    end
  end
end
