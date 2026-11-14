class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships, id: :uuid do |t|
      t.references :household, type: :uuid, null: false, foreign_key: true, index: false
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :role, null: false, default: "adult"
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :memberships, [ :household_id, :user_id ], unique: true
    add_index :memberships, [ :household_id, :role ]
    add_check_constraint :memberships, "role IN ('head', 'adult', 'child')", name: "memberships_role_check"
  end
end
