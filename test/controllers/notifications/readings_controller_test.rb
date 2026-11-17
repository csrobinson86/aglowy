require "test_helper"

# Mark all as read (docs/design/notifications.md, Pages and routes).
class Notifications::ReadingsControllerTest < ActionDispatch::IntegrationTest
  test "Mark all as read reads every visible unread notification and returns to the inbox" do
    first = notify("shared_with_you:1", meeting_notes(:head_midweek))
    second = notify("shared_with_you:2", meeting_notes(:head_weekend))
    sign_in identities(:spouse)

    post household_notifications_readings_path(household_id: households(:home))

    assert_redirected_to household_notifications_path(household_id: households(:home))
    assert first.reload.reading
    assert second.reload.reading
    assert_equal 0, users(:spouse).unread_notifications_count
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)

    post household_notifications_readings_path(household_id: households(:home))

    assert_response :not_found
  end

  private
    def notify(key, subject)
      users(:spouse).notify(kind: "shared_with_you", household: households(:home), subject:, actor: users(:head), dedupe_key: key)
    end
end
