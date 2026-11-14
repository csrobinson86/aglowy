class CreateFamilyStudies < ActiveRecord::Migration[8.1]
  def change
    create_table :family_studies, id: :uuid do |t|
      t.references :household, type: :uuid, null: false, foreign_key: true
      t.string :frequency, null: false, default: "once"
      t.integer :interval, null: false, default: 1
      t.date :starts_on, null: false
      t.integer :week_of_month, limit: 2
      t.time :time_of_day, null: false
      t.integer :duration_minutes, null: false, default: 60
      t.date :ends_on
      t.references :default_conductor, type: :uuid, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_check_constraint :family_studies, "frequency IN ('once', 'daily', 'weekly', 'monthly')", name: "family_studies_frequency_check"
    add_check_constraint :family_studies, %("interval" > 0), name: "family_studies_interval_check"
    add_check_constraint :family_studies, "duration_minutes > 0", name: "family_studies_duration_minutes_check"
    add_check_constraint :family_studies, "week_of_month IN (1, 2, 3, 4, 5, -1)", name: "family_studies_week_of_month_check"
    add_check_constraint :family_studies, "frequency <> 'monthly' OR week_of_month IS NOT NULL", name: "family_studies_monthly_week_of_month_check"
  end
end
