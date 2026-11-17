class CreatePersonalNotePins < ActiveRecord::Migration[8.1]
  # A pinned note, as a record: unpinning deletes it (docs/design/notes.md, PersonalNote::Pin). One per note, which
  # create_or_find_by relies on; it goes with the note.
  def change
    create_table :personal_note_pins, id: :uuid do |t|
      t.references :personal_note, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.datetime :created_at, null: false
    end
  end
end
