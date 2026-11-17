require "application_system_test_case"

# Add to your phone's calendar, on Settings → Calendar (docs/design/calendar.md, Settings → Calendar; frame
# settings-calendar.png, the second box). Hannah Head plays Maria.
class CalendarFeedSettingsTest < ApplicationSystemTestCase
  test "Settings → Calendar shows the link; Reset changes it" do
    sign_in identities(:head)
    visit household_settings_calendar_url(household_id: households(:home))

    feed = users(:head).calendar_feed
    assert_field "Your private link", with: %r{\Awebcal://[^/]+/calendar/#{feed.token}\.ics\z}, readonly: true
    assert_selector "clipboard-copy[for=calendar-feed-url]"
    assert_text "Your phone checks it every few hours. It includes everyone's household events and only your own times."
    assert_accessible
    capture_screens("settings-calendar-feed", scroll_to: "#calendar-feed-url")

    click_on "Reset link"
    within("dialog[open]") do
      assert_text "Your old link stops working. Subscribe again on each device with the new one."
      click_on "Reset link"
    end

    assert_text "Your calendar link is reset."
    assert_not_equal feed.token, feed.reload.token
    assert_field "Your private link", with: %r{/calendar/#{feed.token}\.ics\z}
    assert_accessible
  end
end
