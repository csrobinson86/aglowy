require "test_helper"

# Sunday at 6 PM in the household's zone (docs/design/notifications.md, Recurring jobs; Trap 2).
class Notification::WeeklyPreviewJobTest < ActiveJob::TestCase
  setup do
    households(:home).update!(time_zone: "Central Time (US & Canada)")
    households(:parents).update!(time_zone: "Mountain Time (US & Canada)")
    [ households(:home), households(:parents) ].each do |household|
      household.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    end
  end

  test "runs for a household at Sunday 6 PM in its zone, not one at 5 PM, not a household in another zone where it isn't yet 6 PM" do
    chicago = ActiveSupport::TimeZone["Central Time (US & Canada)"]

    travel_to(chicago.local(2026, 11, 22, 17, 5)) { Notification::WeeklyPreviewJob.perform_now }
    assert_equal 0, Notification.where(kind: "weekly_preview").count

    travel_to(chicago.local(2026, 11, 22, 18, 5)) { Notification::WeeklyPreviewJob.perform_now }
    assert_equal [ households(:home).id ], Notification.where(kind: "weekly_preview").distinct.pluck(:household_id)
    assert_equal [ { "week_of" => "2026-11-23" } ], Notification.where(kind: "weekly_preview").distinct.pluck(:data)
  end
end
