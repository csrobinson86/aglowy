require "test_helper"

# Reset link, on Settings → Calendar: the person's own link, never anyone else's (docs/design/calendar.md, Settings → Calendar).
class Settings::CalendarFeedsControllerTest < ActionDispatch::IntegrationTest
  test "Reset gives the person a new link" do
    feed = users(:eli).ensure_calendar_feed
    old_token = feed.token
    sign_in identities(:eli)

    patch household_settings_calendar_feed_path(household_id: households(:home))

    assert_redirected_to household_settings_calendar_path(household_id: households(:home))
    assert_equal "Your calendar link is reset.", flash[:notice]
    assert_not_equal old_token, feed.reload.token
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)

    patch household_settings_calendar_feed_path(household_id: households(:home))

    assert_response :not_found
  end
end
