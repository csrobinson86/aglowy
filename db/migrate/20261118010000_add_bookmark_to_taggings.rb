class AddBookmarkToTaggings < ActiveRecord::Migration[8.1]
  # Bookmarks can be tagged too (docs/design/bookmarks.md, Bookmark).
  def up
    remove_check_constraint :taggings, name: "taggings_taggable_type_check"
    add_check_constraint :taggings, "taggable_type IN ('MeetingNote', 'Goal', 'PersonalStudy', 'PersonalNote', 'Bookmark')", name: "taggings_taggable_type_check"
  end

  # The narrower check rejects existing bookmark taggings, so they go first.
  def down
    execute "DELETE FROM taggings WHERE taggable_type = 'Bookmark'"
    remove_check_constraint :taggings, name: "taggings_taggable_type_check"
    add_check_constraint :taggings, "taggable_type IN ('MeetingNote', 'Goal', 'PersonalStudy', 'PersonalNote')", name: "taggings_taggable_type_check"
  end
end
