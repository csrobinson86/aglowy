class CreateMeetingNoteAnswers < ActiveRecord::Migration[8.1]
  def change
    # Her answer for the Congregation Bible Study (docs/design/listening-game.md, MeetingNote::Answer): one per note,
    # on the unique index. The body is encrypted, so its 500 characters are checked by the validation only; the
    # database sees the ciphertext.
    create_table :meeting_note_answers, id: :uuid do |t|
      t.references :meeting_note, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.integer :paragraph, limit: 2, null: false
      t.text :body, null: false
      t.timestamps
      t.check_constraint "paragraph > 0", name: "meeting_note_answers_paragraph_check"
    end
  end
end
