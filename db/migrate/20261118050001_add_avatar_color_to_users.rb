class AddAvatarColorToUsers < ActiveRecord::Migration[8.1]
  def change
    # The color of the person's initial (docs/design/avatars.md, User): Avatar::Palette's six. Everyone starts blue.
    add_column :users, :avatar_color, :string, null: false, default: "blue"
    add_check_constraint :users, "avatar_color IN ('blue', 'green', 'purple', 'pink', 'orange', 'yellow')", name: "users_avatar_color_check"
  end
end
