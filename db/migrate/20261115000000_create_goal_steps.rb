class CreateGoalSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :goal_steps, id: :uuid do |t|
      t.references :goal, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :title, null: false
      t.date :due_on
      t.integer :position, null: false
      # Set when the step is scheduled as a study; deleting the study only unlinks the step.
      t.references :family_study, type: :uuid, foreign_key: { on_delete: :nullify }
      # Two adults can edit the same step at once (gotcha 11).
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    # Leads with goal_id, so it also serves the foreign key. Not unique: reordering comes later.
    add_index :goal_steps, %i[ goal_id position ]
  end
end
