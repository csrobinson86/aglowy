class CreateMeetingNotes < ActiveRecord::Migration[8.1]
  def change
    # Personal content: the author is a User, never a household or membership.
    create_table :meeting_notes, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: false
      t.string :kind, null: false
      t.date :week_of, null: false
      t.integer :outline_version, null: false, default: 1

      t.timestamps
    end

    add_check_constraint :meeting_notes, "kind IN ('midweek', 'weekend')", name: "meeting_notes_kind_check"
    add_check_constraint :meeting_notes, "extract(isodow from week_of) = 1", name: "meeting_notes_week_of_monday_check"
    # One note per meeting per person per week; start_meeting_note's create_or_find_by relies on it.
    add_index :meeting_notes, [ :user_id, :kind, :week_of ], unique: true
  end
end
