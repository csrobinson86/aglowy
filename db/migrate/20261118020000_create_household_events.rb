class CreateHouseholdEvents < ActiveRecord::Migration[8.1]
  # A household's own events: assemblies, the circuit overseer's visit, field service and the rest (docs/design/calendar.md,
  # Household::Event). Occurrences are worked out, never stored. The note is encrypted, so its length is checked by a
  # validation only.
  def change
    create_table :household_events, id: :uuid do |t|
      t.references :household, null: false, foreign_key: true, type: :uuid
      t.string :kind, null: false
      t.string :title, null: false
      t.date :starts_on, null: false
      t.integer :days, limit: 2, null: false, default: 1
      t.time :time_of_day
      t.integer :duration_minutes
      t.string :frequency, null: false, default: "once"
      t.integer :interval, null: false, default: 1
      t.integer :week_of_month, limit: 2
      t.date :repeats_until
      t.string :location
      t.string :note
      t.references :created_by, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.timestamps

      t.check_constraint "kind IN ('circuit_assembly', 'regional_convention', 'co_visit', 'memorial', 'field_service', 'other')", name: "household_events_kind_check"
      t.check_constraint "char_length(title) BETWEEN 1 AND 80", name: "household_events_title_length_check"
      t.check_constraint "days BETWEEN 1 AND 14", name: "household_events_days_check"
      t.check_constraint "duration_minutes > 0 AND duration_minutes <= 720", name: "household_events_duration_minutes_check"
      t.check_constraint "(time_of_day IS NULL) = (duration_minutes IS NULL)", name: "household_events_timed_duration_check"
      t.check_constraint "frequency IN ('once', 'weekly', 'monthly')", name: "household_events_frequency_check"
      t.check_constraint "\"interval\" > 0", name: "household_events_interval_check"
      t.check_constraint "week_of_month IN (1, 2, 3, 4, 5, -1)", name: "household_events_week_of_month_check"
      t.check_constraint "frequency <> 'monthly' OR week_of_month IS NOT NULL", name: "household_events_monthly_week_of_month_check"
      t.check_constraint "days = 1 OR (time_of_day IS NULL AND frequency = 'once')", name: "household_events_several_days_check"
      t.check_constraint "char_length(location) <= 120", name: "household_events_location_length_check"
    end
  end
end
