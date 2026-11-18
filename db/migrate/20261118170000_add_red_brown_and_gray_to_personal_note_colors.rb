class AddRedBrownAndGrayToPersonalNoteColors < ActiveRecord::Migration[8.1]
  # Casey's nine colors (docs/design/notes.md, Colors): red, brown and gray join the six, which keep their names.
  def up
    remove_check_constraint :personal_notes, name: "personal_notes_color_check"
    add_check_constraint :personal_notes,
                         "color IN ('none', 'yellow', 'orange', 'red', 'pink', 'purple', 'blue', 'green', 'brown', 'gray')",
                         name: "personal_notes_color_check"
  end

  # The narrower check rejects notes in the new colors, so they lose their color first.
  def down
    execute "UPDATE personal_notes SET color = 'none' WHERE color IN ('red', 'brown', 'gray')"
    remove_check_constraint :personal_notes, name: "personal_notes_color_check"
    add_check_constraint :personal_notes, "color IN ('none', 'yellow', 'green', 'blue', 'purple', 'pink', 'orange')",
                         name: "personal_notes_color_check"
  end
end
