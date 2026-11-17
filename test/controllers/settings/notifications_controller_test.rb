require "test_helper"

# Settings → Notifications, for every role (docs/design/notifications.md, Settings → Notifications; docs/design/settings.md).
# Hannah is a head in home, Sam an adult, Eli a child with a username-only login.
class Settings::NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup { @home = households(:home) }

  test "a head sees all four kinds, each with an Email box, ticked where it's on" do
    users(:head).notification_settings.change([ %w[ weekly_preview email ] ])
    sign_in identities(:head)

    get household_settings_notifications_path(household_id: @home)

    assert_response :success
    assert_select "main h2", "Notifications"
    assert_select "main", text: /What reaches you, and where\. Follows you to every household\./
    assert_select "nav[aria-label='Settings'] a[aria-current=page]", "Notifications"
    assert_equal [ "Weekly preview", "Family study needs a topic", "Shared with you", "Invitation not accepted" ], css_select("main fieldset legend").map { it.text.strip }
    assert_select "form[action=?] input[type=checkbox][name='notification_settings[weekly_preview][]'][value=email][checked]", household_settings_notifications_path(household_id: @home)
    %w[ study_topic_needed shared_with_you invitation_unaccepted ].each do |kind|
      assert_select "input[type=checkbox][name='notification_settings[#{kind}][]'][value=email]:not([checked])"
    end
    assert_select "main", text: /Sunday evening: each household's week ahead\./
    assert_select "main", text: /In Aglowy: always\./
    assert_select "main", text: /Emails go to head@example\.com\. "Right away" sends when it happens; the rest wait for your daily summary at 7:00 AM\./
  end

  test "an adult sees the invitation kind but not the topic kind" do
    sign_in identities(:spouse)

    get household_settings_notifications_path(household_id: @home)

    assert_equal [ "Weekly preview", "Shared with you", "Invitation not accepted" ], css_select("main fieldset legend").map { it.text.strip }
    assert_select "input[type=checkbox][value=email]", count: 3
  end

  test "a child's form has no Email" do
    sign_in identities(:eli)

    get household_settings_notifications_path(household_id: @home)

    assert_response :success
    assert_equal [ "Weekly preview", "Shared with you" ], css_select("main fieldset legend").map { it.text.strip }
    assert_select "input[type=checkbox]", count: 0
    assert_select "main", text: /Children get notifications in Aglowy and on their phone, never by email\./
    assert_select "main", text: /Emails go to/, count: 0
    assert_select "select[name='user[quiet_hours_start]']"
  end

  test "an adult with a username-only login has no Email either, and is told why" do
    identities(:spouse).update_columns(email: nil, username: "sam.spouse")
    sign_in identities(:spouse)

    get household_settings_notifications_path(household_id: @home)

    assert_select "input[type=checkbox]", count: 0
    assert_select "main", text: /Your login has no email address, so nothing is emailed\./
  end

  test "saves, and comes back to Notifications" do
    users(:head).notification_settings.change([ %w[ weekly_preview email ] ])
    sign_in identities(:head)

    patch household_settings_notifications_path(household_id: @home), params: { notification_settings: { sent: "1", study_topic_needed: [ "email" ], shared_with_you: [ "email" ] } }

    assert_redirected_to household_settings_notifications_path(household_id: @home)
    assert_equal "Your notifications are saved.", flash[:notice]
    assert_equal [ %w[ shared_with_you email ], %w[ study_topic_needed email ] ], users(:head).notification_settings.pluck(:kind, :channel).sort
  end

  test "nothing ticked turns everything off" do
    users(:head).notification_settings.change([ %w[ weekly_preview email ] ])
    sign_in identities(:head)

    patch household_settings_notifications_path(household_id: @home), params: { notification_settings: { sent: "1" } }

    assert_redirected_to household_settings_notifications_path(household_id: @home)
    assert_empty users(:head).notification_settings
  end

  test "a kind the person isn't offered, a channel that doesn't exist and a child's email are ignored" do
    sign_in identities(:spouse)
    patch household_settings_notifications_path(household_id: @home), params: { notification_settings: { study_topic_needed: [ "email" ], weekly_preview: [ "sms", "email" ], streak_missed: [ "email" ] } }
    assert_equal [ %w[ weekly_preview email ] ], users(:spouse).notification_settings.pluck(:kind, :channel)

    sign_in identities(:eli)
    patch household_settings_notifications_path(household_id: @home), params: { notification_settings: { weekly_preview: [ "email" ] } }
    assert_empty users(:eli).notification_settings
  end

  test "quiet hours are shown on the half hour in the person's zone, and saved" do
    users(:head).update!(time_zone: "Central Time (US & Canada)")
    sign_in identities(:head)

    get household_settings_notifications_path(household_id: @home)

    assert_select "form[action=?]", household_settings_quiet_hours_path(household_id: @home) do
      assert_select "select[name='user[quiet_hours_start]'] option", count: 48
      assert_select "select[name='user[quiet_hours_start]'] option[value='21:00'][selected]", "9:00 PM"
      assert_select "select[name='user[quiet_hours_end]'] option[value='07:00'][selected]", "7:00 AM"
    end
    assert_select "main", text: /Nothing is emailed or sent to your phone during quiet hours\. It waits until they end\. Times are in Central Time, your time zone in Profile\./

    patch household_settings_quiet_hours_path(household_id: @home), params: { user: { quiet_hours_start: "22:30", quiet_hours_end: "06:00" } }

    assert_redirected_to household_settings_notifications_path(household_id: @home)
    assert_equal "Your quiet hours are saved.", flash[:notice]
    assert_equal %w[ 22:30 06:00 ], [ users(:head).reload.quiet_hours_start, users(:head).quiet_hours_end ].map { it.strftime("%H:%M") }
  end

  test "quiet hours off the half hour are refused, and only quiet hours are saved from that form" do
    sign_in identities(:eli)

    patch household_settings_quiet_hours_path(household_id: @home), params: { user: { quiet_hours_start: "22:10", quiet_hours_end: "06:00", name: "Someone Else" } }

    assert_response :unprocessable_content
    assert_select "main h2", "Notifications"
    assert_select "main", text: /must be on the hour or the half hour/
    assert_equal "Eli Child", users(:eli).reload.name
    assert_equal "21:00", users(:eli).quiet_hours_start.strftime("%H:%M")
  end

  test "a non-member gets a 404 and saves nothing" do
    sign_in identities(:outsider)

    get household_settings_notifications_path(household_id: @home)
    assert_response :not_found

    patch household_settings_notifications_path(household_id: @home), params: { notification_settings: { weekly_preview: [ "email" ] } }
    assert_response :not_found
    assert_empty users(:outsider).notification_settings

    patch household_settings_quiet_hours_path(household_id: @home), params: { user: { quiet_hours_start: "22:00", quiet_hours_end: "06:00" } }
    assert_response :not_found
    assert_equal "21:00", users(:outsider).reload.quiet_hours_start.strftime("%H:%M")
  end

  test "signed out goes to sign in" do
    get household_settings_notifications_path(household_id: @home)

    assert_redirected_to new_identity_session_path
  end
end
