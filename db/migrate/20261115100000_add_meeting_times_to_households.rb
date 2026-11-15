# When the household's congregation meets (docs/design/meeting-helper.md, Meeting times). Days are Ruby's wday, Sunday 0;
# times are wall-clock times in the household's time zone. They're set together.
class AddMeetingTimesToHouseholds < ActiveRecord::Migration[8.1]
  def change
    change_table :households, bulk: true do |t|
      t.integer :midweek_meeting_wday, limit: 2
      t.time :midweek_meeting_time
      t.integer :weekend_meeting_wday, limit: 2
      t.time :weekend_meeting_time
    end

    add_check_constraint :households, "midweek_meeting_wday BETWEEN 0 AND 6", name: "households_midweek_meeting_wday_check"
    add_check_constraint :households, "weekend_meeting_wday BETWEEN 0 AND 6", name: "households_weekend_meeting_wday_check"
    add_check_constraint :households,
      "num_nulls(midweek_meeting_wday, midweek_meeting_time, weekend_meeting_wday, weekend_meeting_time) IN (0, 4)",
      name: "households_meeting_times_check"
  end
end
