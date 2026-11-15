class CreateGoalArchivals < ActiveRecord::Migration[8.1]
  def change
    # Archival is a record, not a flag: restoring deletes it (docs/design/goals.md, Goal).
    create_table :goal_archivals, id: :uuid do |t|
      t.references :goal, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.references :archived_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.datetime :created_at, null: false
    end
  end
end
