class CreateMeetingNoteGems < ActiveRecord::Migration[8.1]
  def change
    # The reference columns aren't personal and stay plain so gems can sort in Bible order; the insight is encrypted.
    create_table :meeting_note_gems, id: :uuid do |t|
      t.references :meeting_note, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :scripture, null: false
      t.integer :book_number, limit: 2, null: false
      t.integer :chapter, limit: 2, null: false
      t.integer :verse_start, limit: 2
      t.integer :verse_end, limit: 2
      t.text :insight
      t.integer :position, null: false

      t.timestamps
    end

    add_check_constraint :meeting_note_gems, "book_number BETWEEN 1 AND 66", name: "meeting_note_gems_book_number_check"
    add_check_constraint :meeting_note_gems, "chapter > 0", name: "meeting_note_gems_chapter_check"
  end
end
