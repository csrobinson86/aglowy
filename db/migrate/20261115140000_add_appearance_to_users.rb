class AddAppearanceToUsers < ActiveRecord::Migration[8.1]
  def change
    # The person's theme (docs/design/app-shell.md, Theming and appearance). Everyone starts on auto, so nothing
    # changes until they choose.
    add_column :users, :appearance, :string, null: false, default: "auto"
    add_check_constraint :users, "appearance IN ('auto', 'light', 'dark')", name: "users_appearance_check"
  end
end
