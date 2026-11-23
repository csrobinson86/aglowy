require "test_helper"

# Every hour at minute 20, each household where it's the 8 AM hour is reminded about its go-bag use-by dates
# (docs/design/go-bags.md, The use-by reminder).
class Notification::GoBagUseByJobTest < ActiveJob::TestCase
  CHICAGO = ActiveSupport::TimeZone["Central Time (US & Canada)"]

  setup do
    households(:home).update!(time_zone: CHICAGO.name)
    households(:other).update!(time_zone: "Tokyo")
    go_bag_items(:water).update!(use_by: Date.new(2026, 12, 7))
    @theirs = households(:other).go_bags.create!(name: "Their bag", created_by: users(:outsider)).items.create!(name: "Water", use_by: Date.new(2026, 12, 7))
    @theirs.acquire(by: users(:outsider))
  end

  test "only households at their 8 AM hour" do
    travel_to(CHICAGO.local(2026, 11, 17, 8, 20)) { Notification::GoBagUseByJob.perform_now }

    assert_equal 2, Notification.where(subject: go_bag_items(:water)).count
    assert_not Notification.exists?(subject: @theirs)
  end

  test "not at 9 AM" do
    travel_to(CHICAGO.local(2026, 11, 17, 9, 20)) { Notification::GoBagUseByJob.perform_now }

    assert_not Notification.exists?(kind: "go_bag_use_by")
  end
end
