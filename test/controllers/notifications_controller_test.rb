require "test_helper"

# The inbox and opening one (docs/design/notifications.md, Pages and routes, The inbox).
class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 11, 18, 15)
    sign_in identities(:head)
  end

  test "the inbox lists only your visible notifications, newest first, grouped Today and Earlier" do
    earlier = travel_to(2.days.ago) { notify(users(:head), meeting_notes(:head_weekend), actor: users(:spouse), key: "shared_with_you:1") }
    today = notify(users(:head), goals(:spouse_bible_reading), actor: users(:spouse), key: "shared_with_you:2")
    notify(users(:spouse), meeting_notes(:head_midweek), actor: users(:head), key: "shared_with_you:3")
    left = notify(users(:head), goals(:spouse_bible_reading), household: households(:parents), actor: users(:grandparent), key: "shared_with_you:4")
    memberships(:head_in_parents).deactivate
    earlier.read

    get household_notifications_path(household_id: households(:home))

    assert_response :success
    assert_select "title", "Notifications · The Head Family · Aglowy"
    assert_select "h1", "Notifications"
    assert_select ".Subhead", text: /From all your households. Kept for 90 days./
    assert_select "ul[aria-label='Show'] a[aria-current='true']", text: "All"
    assert_select "ul[aria-label='Show'] a[href='#{household_notifications_path(household_id: households(:home), show: "unread")}']", text: /Unread\s+\(1\)/
    assert_select "main .Box-row", count: 2
    assert_select "main h2", text: "Today"
    assert_select "main h2", text: "Earlier"
    assert_select "main .Box-row:first-child a[href='#{household_notification_path(household_id: households(:home), id: today)}']", text: /Sam shared a goal/
    assert_select "main .Box-row:first-child", text: /\(unread\)/
    assert_select "main .Box-row:first-child", text: /Read the whole Bible in a year/
    assert_select "main .Box-row:first-child", text: /The Head Family · 3:00 PM/
    assert_select "main .Box-row a[href='#{household_notification_path(household_id: households(:home), id: earlier)}']", text: "Sam shared a meeting note"
    assert_select "main .Box-row", text: /Weekend meeting · week of November 16/
    assert_select "a[href='#{household_notification_path(household_id: households(:home), id: left)}']", count: 0
    assert_select "form[action='#{household_notifications_readings_path(household_id: households(:home))}'] button", text: "Mark all as read"
  end

  test "a renamed household shows its new name on the row" do
    notify(users(:head), goals(:spouse_bible_reading), actor: users(:spouse), key: "shared_with_you:1")
    households(:home).update!(name: "The Renamed Family")

    get household_notifications_path(household_id: households(:home))

    assert_select "main .Box-row", text: /The Renamed Family · 3:00 PM/
  end

  test "show=unread lists only unread ones" do
    read = notify(users(:head), meeting_notes(:head_weekend), actor: users(:spouse), key: "shared_with_you:1")
    unread = notify(users(:head), goals(:spouse_bible_reading), actor: users(:spouse), key: "shared_with_you:2")
    read.read

    get household_notifications_path(household_id: households(:home), show: "unread")

    assert_response :success
    assert_select "ul[aria-label='Show'] a[aria-current='true']", text: /Unread\s+\(1\)/
    assert_select "main .Box-row", count: 1
    assert_select "main .Box-row a[href='#{household_notification_path(household_id: households(:home), id: unread)}']"
  end

  test "with none, the blankslate, and no Mark all as read" do
    get household_notifications_path(household_id: households(:home))

    assert_select ".blankslate h2", "You're all caught up"
    assert_select ".blankslate", text: /New notifications from your households show up here./
    assert_select "button", text: "Mark all as read", count: 0
    # Settings → Notifications comes in a later NOTIFY-01 story; a link appears once its page exists.
    assert_select "a", text: "Notification settings", count: 0
  end

  test "pages at 50" do
    51.times { |n| travel_to(n.minutes.ago) { notify(users(:head), meeting_notes(:head_midweek), actor: users(:spouse), key: "shared_with_you:#{n}") } }

    get household_notifications_path(household_id: households(:home))

    assert_select "main .Box-row", count: 50
    assert_select "a[href='#{household_notifications_path(household_id: households(:home), page: 2)}']", text: "Older notifications"

    get household_notifications_path(household_id: households(:home), page: 2)

    assert_select "main .Box-row", count: 1
    assert_select "a[href='#{household_notifications_path(household_id: households(:home), page: 1)}']", text: "Newer notifications"
  end

  test "a later page that's become empty goes to the last page with notifications" do
    notifications = Array.new(51) { |n| travel_to(n.minutes.ago) { notify(users(:head), meeting_notes(:head_midweek), actor: users(:spouse), key: "shared_with_you:#{n}") } }

    get household_notifications_path(household_id: households(:home), show: "unread", page: 3)
    assert_redirected_to household_notifications_path(household_id: households(:home), show: "unread", page: 2)

    notifications.last.read
    get household_notifications_path(household_id: households(:home), show: "unread", page: 2)
    assert_redirected_to household_notifications_path(household_id: households(:home), show: "unread")
  end

  test "a row's link isn't prefetched on hover, since opening it reads it" do
    notification = notify(users(:head), goals(:spouse_bible_reading), actor: users(:spouse), key: "shared_with_you:1")

    get household_notifications_path(household_id: households(:home))

    assert_select "a[href='#{household_notification_path(household_id: households(:home), id: notification)}'][data-turbo-prefetch='false']"
  end

  test "show marks it read and redirects to the target, under the notification's own household" do
    notification = notify(users(:head), goals(:spouse_bible_reading), household: households(:parents), actor: users(:spouse), key: "shared_with_you:1")

    get household_notification_path(household_id: households(:home), id: notification)

    assert_redirected_to household_goal_path(household_id: households(:parents), id: goals(:spouse_bible_reading))
    assert notification.reload.reading
  end

  test "someone else's notification is a 404" do
    notification = notify(users(:spouse), meeting_notes(:head_midweek), actor: users(:head), key: "shared_with_you:1")

    get household_notification_path(household_id: households(:home), id: notification)

    assert_response :not_found
    assert_nil notification.reload.reading
  end

  test "one from a household you left is a 404" do
    notification = notify(users(:head), goals(:spouse_bible_reading), household: households(:parents), actor: users(:grandparent), key: "shared_with_you:1")
    memberships(:head_in_parents).deactivate

    get household_notification_path(household_id: households(:home), id: notification)

    assert_response :not_found
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)

    get household_notifications_path(household_id: households(:home))

    assert_response :not_found
  end

  private
    def notify(user, subject, actor:, key:, household: households(:home))
      user.notify(kind: "shared_with_you", household:, subject:, actor:, dedupe_key: key)
    end
end
