class CreateGoalStepAssignments < ActiveRecord::Migration[8.1]
  def change
    # No assignments means the step is for everyone (docs/design/goals.md, Goal::Step::Assignment).
    create_table :goal_step_assignments, id: :uuid do |t|
      t.references :step, type: :uuid, null: false, foreign_key: { to_table: :goal_steps, on_delete: :cascade }, index: false
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :created_at, null: false
    end

    add_index :goal_step_assignments, %i[ step_id user_id ], unique: true
  end
end
