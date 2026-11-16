class AddPersonalNoteToTaggings < ActiveRecord::Migration[8.1]
  # Notes can be tagged too (docs/design/tags.md, Tagging).
  def up
    remove_check_constraint :taggings, name: "taggings_taggable_type_check"
    add_check_constraint :taggings, "taggable_type IN ('MeetingNote', 'Goal', 'PersonalStudy', 'PersonalNote')", name: "taggings_taggable_type_check"
  end

  # The narrower check rejects existing note taggings, so they go first.
  def down
    execute "DELETE FROM taggings WHERE taggable_type = 'PersonalNote'"
    remove_check_constraint :taggings, name: "taggings_taggable_type_check"
    add_check_constraint :taggings, "taggable_type IN ('MeetingNote', 'Goal', 'PersonalStudy')", name: "taggings_taggable_type_check"
  end
end
