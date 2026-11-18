require "application_system_test_case"

# Settings → Notifications and the "Turn off this email" page (docs/design/notifications.md, Settings → Notifications
# and Emails; frames settings-notifications.png and settings-notifications-child.png). The Phone column and the
# Phones and browsers box are in push_settings_test.rb.
class NotificationSettingsTest < ApplicationSystemTestCase
  test "a head turns on the weekly email and changes quiet hours" do
    users(:head).update!(time_zone: "Central Time (US & Canada)")
    sign_in identities(:head)
    visit household_settings_profile_url(household_id: households(:home))

    within("nav[aria-label='Settings']") { click_on "Notifications" }

    assert_selector "h2", text: "Notifications"
    assert_selector "nav[aria-label='Settings'] a[aria-current=page]", text: "Notifications"
    assert_selector "aside nav a[aria-current=page]", text: "Settings"
    assert_text "Emails go to head@example.com."
    assert_accessible

    within_fieldset("Weekly preview") { check "Email" }
    capture_screens("settings-notifications")
    within("#notification-settings") { click_on "Save" }

    assert_text "Your notifications are saved."
    within_fieldset("Weekly preview") { assert_checked_field "Email" }
    within_fieldset("Shared with you") { assert_unchecked_field "Email" }
    assert_equal [ %w[ weekly_preview email ] ], users(:head).notification_settings.pluck(:kind, :channel)

    select "10:30 PM", from: "From"
    select "6:00 AM", from: "Until"
    within("#quiet-hours") { click_on "Save" }

    assert_text "Your quiet hours are saved."
    assert_field "From", with: "22:30"
    assert_field "Until", with: "06:00"
    assert_text "the rest wait for your daily summary at 6:00 AM."
  end

  test "a child sees their two kinds with no Email, and quiet hours" do
    sign_in identities(:eli)
    visit household_settings_notifications_url(household_id: households(:home))

    assert_selector "legend", text: "Weekly preview"
    assert_selector "legend", text: "Shared with you"
    assert_no_selector "legend", text: "Invitation not accepted"
    assert_no_field "Email"
    assert_text "Children get notifications in Aglowy and on their phone, never by email."
    assert_field "From", with: "21:00"
    assert_accessible
    capture_screens("settings-notifications-child")
  end

  test "Turn off this email, signed out: the page has one button, and pressing it turns the email off" do
    head = users(:head)
    head.notification_settings.change([ %w[ weekly_preview email ], %w[ shared_with_you email ] ])

    visit email_unsubscribe_url(scope: "weekly_preview", token: head.unsubscribe_token("weekly_preview"))

    assert_selector "h1", text: "Turn off Weekly preview emails?"
    assert_accessible
    capture_screens("email-unsubscribe")
    assert_equal 2, head.notification_settings.count, "opening the page changes nothing"

    click_on "Turn off this email"

    assert_selector "h1", text: "Weekly preview emails are off"
    assert_accessible
    assert_equal [ "shared_with_you" ], head.notification_settings.pluck(:kind)

    visit email_unsubscribe_url(scope: "summary", token: "nonsense")

    assert_text "This link no longer works. Change emails in Settings → Notifications."
    assert_accessible
  end
end
