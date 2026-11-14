class CreateGoals < ActiveRecord::Migration[8.1]
  def change
    # A family goal belongs to a household, a personal goal to a person: two foreign keys and a check,
    # not a polymorphic owner, so both keep their foreign key (gotcha 9, docs/design/goals.md).
    create_table :goals, id: :uuid do |t|
      t.references :household, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :user, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :set_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :kind, null: false, default: "milestone"
      t.string :title, null: false
      t.text :body
      t.date :target_on, null: false
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_check_constraint :goals, "num_nonnulls(household_id, user_id) = 1", name: "goals_one_owner_check"
    # Habit goals widen this check rather than adding a column.
    add_check_constraint :goals, "kind IN ('milestone')", name: "goals_kind_check"
  end
end
