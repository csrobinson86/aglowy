require "test_helper"

class NotificationsHelperTest < ActionView::TestCase
  setup { travel_to Time.utc(2026, 11, 18, 15) }

  test "a time today, in the week before, and before that, in the person's zone" do
    assert_equal "10:00 AM", notification_time(Notification.new(created_at: Time.utc(2026, 11, 18, 15)), "America/New_York")
    assert_equal "Friday", notification_time(Notification.new(created_at: Time.utc(2026, 11, 13, 12)), "America/New_York")
    assert_equal "November 3", notification_time(Notification.new(created_at: Time.utc(2026, 11, 3, 12)), "America/New_York")
  end

  test "late last night in the person's zone is Earlier, even when it's today in UTC" do
    late = Notification.new(created_at: Time.utc(2026, 11, 18, 4))

    assert_equal({ "Earlier" => [ late ] }, notifications_by_day([ late ], "America/New_York"))
  end
end
