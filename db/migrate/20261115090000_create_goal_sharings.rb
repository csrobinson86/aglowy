class CreateGoalSharings < ActiveRecord::Migration[8.1]
  def change
    # Sharing is a record, not a flag: stopping deletes it (docs/design/goals.md, Goal::Sharing).
    create_table :goal_sharings, id: :uuid do |t|
      t.references :goal, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :household, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :created_at, null: false
    end

    # Leads with goal_id, so it also serves a goal's own sharings.
    add_index :goal_sharings, %i[ goal_id household_id ], unique: true
  end
end
