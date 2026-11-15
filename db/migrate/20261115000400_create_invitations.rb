class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    # An open household invitation (docs/design/invitations.md, "Invitation"). The token is never stored:
    # generates_token_for derives it from the row, and accepting, declining or cancelling deletes the row.
    create_table :invitations, id: :uuid do |t|
      t.references :household, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :email, null: false
      t.string :role, null: false, default: "adult"
      t.references :invited_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.datetime :expires_at, null: false
      t.timestamps
    end

    # One open invitation per address per household. Children get usernames, not invitations.
    add_index :invitations, %i[ household_id email ], unique: true
    add_check_constraint :invitations, "role IN ('adult', 'head')", name: "invitations_role_check"
  end
end
