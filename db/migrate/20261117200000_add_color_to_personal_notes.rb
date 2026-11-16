class AddColorToPersonalNotes < ActiveRecord::Migration[8.1]
  def change
    # A note's color, like JW Library's (docs/design/notes.md, Colors). Every note has one; none is no color.
    add_column :personal_notes, :color, :string, null: false, default: "none"
    add_check_constraint :personal_notes, "color IN ('none', 'yellow', 'green', 'blue', 'purple', 'pink', 'orange')",
                         name: "personal_notes_color_check"
  end
end
