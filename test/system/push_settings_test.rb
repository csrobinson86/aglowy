require "application_system_test_case"

# Settings → Notifications' Phone column and the Phones and browsers box (docs/design/notifications.md, Settings →
# Notifications; frames settings-notifications.png and settings-notifications-child.png). The browser's permission
# prompt isn't automated: the Stimulus controller's paths are covered by the request and job tests.
class PushSettingsTest < ApplicationSystemTestCase
  setup { travel_to Time.utc(2026, 11, 17, 18) }

  test "the Phone checkboxes save" do
    sign_in identities(:head)
    visit household_settings_notifications_url(household_id: households(:home))

    within_fieldset("Weekly preview") { check "Email" }
    within_fieldset("Family study needs a topic") { check "Phone" }
    within_fieldset("Shared with you") { check "Phone" }
    within("#notification-settings") { click_on "Save" }

    assert_text "Your notifications are saved."
    within_fieldset("Family study needs a topic") { assert_checked_field "Phone" }
    within_fieldset("Weekly preview") { assert_unchecked_field "Phone" }
    assert_equal [ %w[ shared_with_you push ], %w[ study_topic_needed push ], %w[ weekly_preview email ] ],
                 users(:head).notification_settings.pluck(:kind, :channel).sort
    assert_accessible
    capture_screens("settings-notifications-push", scroll_to: "#push-subscriptions")
  end

  test "a child's Phone checkboxes save, with no Email" do
    users(:eli).push_subscriptions.subscribe(endpoint: "https://web.push.apple.com/QEliIpad", p256dh_key: "BKey", auth_key: "Auth",
                                             user_agent: "Mozilla/5.0 (iPad; CPU OS 18_1 like Mac OS X)", standalone: true)
    sign_in identities(:eli)
    visit household_settings_notifications_url(household_id: households(:home))

    assert_no_field "Email"
    within_fieldset("Shared with you") { check "Phone" }
    within("#notification-settings") { click_on "Save" }

    assert_text "Your notifications are saved."
    assert_equal [ %w[ shared_with_you push ] ], users(:eli).notification_settings.pluck(:kind, :channel)
    within("#push-subscriptions") { assert_text "iPad · Aglowy on the Home Screen" }
    assert_accessible
    capture_screens("settings-notifications-push-child", scroll_to: "#push-subscriptions")
  end

  test "a device listed can be removed" do
    sign_in identities(:head)
    visit household_settings_notifications_url(household_id: households(:home))

    within("#push-subscriptions") do
      assert_text "iPhone · Aglowy on the Home Screen"
      assert_text "Added November 12 · last used today"
      assert_text "Chrome on Mac"
      assert_text "Added November 3"
      assert_text "On an iPhone or iPad, add Aglowy to your Home Screen first (Share, then Add to Home Screen), open it from there, and turn notifications on."
    end
    assert_accessible

    within("#push_subscription_#{push_subscriptions(:head_mac).id}") { click_on "Remove" }

    assert_text "Chrome on Mac is removed."
    within("#push-subscriptions") do
      assert_no_text "Chrome on Mac"
      assert_text "iPhone · Aglowy on the Home Screen"
    end
    assert_equal [ push_subscriptions(:head_iphone) ], users(:head).push_subscriptions.to_a
    assert_accessible
  end
end
