class CreateFamilyStudySessions < ActiveRecord::Migration[8.1]
  def change
    create_table :family_study_sessions, id: :uuid do |t|
      t.references :family_study, type: :uuid, null: false, foreign_key: true, index: false
      t.datetime :recurrence_at, null: false
      t.datetime :scheduled_at, null: false
      t.string :topic
      t.references :conductor, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :detached_at
      t.datetime :canceled_at

      t.timestamps
    end

    # The generator can't duplicate a session, even a moved one (gotcha 21).
    add_index :family_study_sessions, [ :family_study_id, :recurrence_at ], unique: true, name: "index_family_study_sessions_on_study_and_recurrence_at"
    add_index :family_study_sessions, :scheduled_at
  end
end
