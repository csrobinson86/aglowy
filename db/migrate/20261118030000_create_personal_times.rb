class CreatePersonalTimes < ActiveRecord::Migration[8.1]
  # A person's own times on the calendar and their done marks (docs/design/calendar.md, PersonalTime and
  # PersonalTime::Completion). Occurrences are worked out, never stored. The title is encrypted, so its length is checked
  # by a validation only.
  def change
    create_table :personal_times, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :kind, null: false
      t.string :title, null: false
      t.integer :wdays, limit: 2, array: true, null: false
      t.time :time_of_day, null: false
      t.integer :duration_minutes, null: false, default: 30
      t.date :starts_on, null: false, default: -> { "CURRENT_DATE" }
      t.string :opens_type
      t.uuid :opens_id
      t.timestamps

      t.index %i[ opens_type opens_id ]
      t.check_constraint "kind IN ('bible_reading', 'personal_study', 'meeting_prep', 'other')", name: "personal_times_kind_check"
      t.check_constraint "cardinality(wdays) BETWEEN 1 AND 7 AND wdays <@ '{0,1,2,3,4,5,6}'", name: "personal_times_wdays_check"
      t.check_constraint "duration_minutes BETWEEN 5 AND 240", name: "personal_times_duration_minutes_check"
      t.check_constraint "opens_type IN ('PersonalStudy', 'PersonalNote')", name: "personal_times_opens_type_check"
      t.check_constraint "(opens_type IS NULL) = (opens_id IS NULL)", name: "personal_times_opens_check"
    end

    create_table :personal_time_completions, id: :uuid do |t|
      t.references :personal_time, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.date :on, null: false
      t.datetime :created_at, null: false

      t.index %i[ personal_time_id on ], unique: true
    end
  end
end
