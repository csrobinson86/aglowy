# A login is an email, a username or both (docs/design/invitations.md,
# "Signing in with an email or a username").
class AddUsernameToIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :identities, :username, :string
    add_index :identities, "lower(username)", unique: true, name: "index_identities_on_lower_username"
    add_check_constraint :identities, "username ~ '^[a-z0-9][a-z0-9.-]{2,29}$'", name: "identities_username_format_check"

    change_column_default :identities, :email, from: "", to: nil
    change_column_null :identities, :email, true
    up_only { execute "UPDATE identities SET email = NULL WHERE email = ''" }
    add_check_constraint :identities, "num_nonnulls(email, username) >= 1", name: "identities_email_or_username_check"
    add_check_constraint :identities, "email <> ''", name: "identities_email_not_blank_check"
  end
end
