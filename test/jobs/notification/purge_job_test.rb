require "test_helper"

# Kept for 90 days (docs/design/notifications.md, Models).
class Notification::PurgeJobTest < ActiveJob::TestCase
  test "removes notifications older than 90 days with their readings" do
    old = travel_to(91.days.ago) { notify("shared_with_you:1").tap(&:read) }
    kept = travel_to(89.days.ago) { notify("shared_with_you:2").tap(&:read) }

    Notification::PurgeJob.perform_now

    assert_not Notification.exists?(old.id)
    assert_not Notification::Reading.exists?(notification_id: old.id)
    assert Notification.exists?(kept.id)
    assert Notification::Reading.exists?(notification_id: kept.id)
  end

  private
    def notify(dedupe_key)
      users(:spouse).notify(kind: "shared_with_you", household: households(:home), subject: meeting_notes(:head_midweek), actor: users(:head), dedupe_key:)
    end
end
