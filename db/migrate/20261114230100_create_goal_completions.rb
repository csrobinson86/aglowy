class CreateGoalCompletions < ActiveRecord::Migration[8.1]
  def change
    # Completion is a record, not a flag: reopening deletes it (docs/design/goals.md, Goal).
    create_table :goal_completions, id: :uuid do |t|
      t.references :goal, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.references :completed_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.datetime :created_at, null: false
    end
  end
end
