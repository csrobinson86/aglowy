class AddPersonalNoteToTaggings < ActiveRecord::Migration[8.1]
  # Notes can be tagged too (docs/design/tags.md, Tagging).
  def change
    remove_check_constraint :taggings, "taggable_type IN ('MeetingNote', 'Goal', 'PersonalStudy')", name: "taggings_taggable_type_check"
    add_check_constraint :taggings, "taggable_type IN ('MeetingNote', 'Goal', 'PersonalStudy', 'PersonalNote')", name: "taggings_taggable_type_check"
  end
end
