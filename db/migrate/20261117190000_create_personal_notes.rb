class CreatePersonalNotes < ActiveRecord::Migration[8.1]
  def change
    # One person's note to come back to (docs/design/notes.md, PersonalNote). Its color comes with the next story;
    # deleting a collection keeps its notes, out of any folder.
    create_table :personal_notes, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :collection, foreign_key: { on_delete: :nullify }, type: :uuid
      t.string :title, null: false
      t.timestamps

      t.check_constraint "char_length(title) BETWEEN 1 AND 120", name: "personal_notes_title_length_check"
    end
  end
end
