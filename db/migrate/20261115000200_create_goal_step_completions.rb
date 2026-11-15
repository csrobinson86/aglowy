class CreateGoalStepCompletions < ActiveRecord::Migration[8.1]
  def change
    # A tick: whose part it is (user_id, null when done together) and who ticked it (docs/design/goals.md).
    create_table :goal_step_completions, id: :uuid do |t|
      t.references :step, type: :uuid, null: false, foreign_key: { to_table: :goal_steps, on_delete: :cascade }, index: false
      t.references :user, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :completed_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.datetime :created_at, null: false
    end

    # One tick per person per step, and NULLS NOT DISTINCT makes it one "done together" tick too.
    # NULLS NOT DISTINCT needs PostgreSQL 15 or later.
    add_index :goal_step_completions, %i[ step_id user_id ], unique: true, nulls_not_distinct: true
  end
end
