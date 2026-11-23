require "application_system_test_case"

# docs/design/notifications.md, The sidebar and The inbox; frames notifications.png, notifications-unread.png,
# notifications-dark.png and phone-notifications.png.
class NotificationsTest < ApplicationSystemTestCase
  test "Daniel shares a meeting note; Maria's counter shows 1 without reloading; she opens it from the inbox and lands on the note; the counter clears" do
    # Sam shares with Hannah's household here, as Daniel does with Maria's in the frames.
    note = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    assert_no_selector "nav[aria-label='Main settings'] .Counter"

    note.share_with(households(:home))

    assert_link "Notifications, 1 unread"
    assert_selector "nav[aria-label='Main settings'] .Counter", text: "1"

    click_on "Notifications, 1 unread"
    assert_selector "h1", text: "Notifications"
    click_on "Sam shared a meeting note"

    assert_current_path household_meeting_note_path(household_id: households(:home), id: note)
    assert_text "Shared by Sam Spouse"
    assert_no_link "Notifications, 1 unread"
    assert_no_selector "nav[aria-label='Main settings'] .Counter"
  end

  test "Mark all as read clears the list's unread dots and the counter" do
    share_a_few_with_hannah
    sign_in identities(:head)
    visit household_notifications_url(household_id: households(:home))

    click_on "Unread (2)"
    assert_selector "main .Box-row", count: 2
    assert_selector "nav[aria-label='Main settings'] .Counter", text: "2"
    click_on "Mark all as read"

    assert_link "Unread (0)"
    assert_selector "main .Box-row", count: 3
    assert_no_selector "main .Box-row .octicon-dot-fill"
    assert_no_button "Mark all as read"
    assert_no_selector "nav[aria-label='Main settings'] .Counter"
  end

  test "the inbox passes assert_accessible in light and dark, on a desktop and a phone" do
    share_a_few_with_hannah
    sign_in identities(:head)
    visit household_notifications_url(household_id: households(:home))

    assert_selector "main .Box-row", count: 3
    assert_accessible
    capture_screens("notifications")

    users(:head).update!(appearance: "dark")
    visit household_notifications_url(household_id: households(:home))
    assert_selector "body[data-color-mode='dark']"
    assert_accessible

    users(:head).update!(appearance: "auto")
    page.driver.browser.manage.window.resize_to(390, 844)
    visit household_notifications_url(household_id: households(:home))
    assert_selector "header a[href='#{household_notifications_path(household_id: households(:home))}']"
    assert_accessible
    capture_screens("phone-notifications", viewports: { phone: ScreenshotHelper::VIEWPORTS[:phone] })
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "the empty inbox passes assert_accessible" do
    sign_in identities(:head)
    visit household_notifications_url(household_id: households(:home))

    assert_text "You're all caught up"
    assert_accessible
    capture_screens("notifications-empty")
  end

  test "go bag use-by dates: a head sees the kind in Settings → Notifications, and opening the reminder goes to the item's page" do
    water = go_bag_items(:water)
    water.update!(use_by: households(:home).today + 20)
    water.remind_about_use_by_now
    sign_in identities(:head)

    visit household_settings_notifications_url(household_id: households(:home))
    assert_selector "legend", text: "Go bag use-by dates"
    assert_text "A month before something in a go bag needs replacing. Heads and adults."

    visit household_notifications_url(household_id: households(:home))
    assert_selector "main .notification-row__icon--yellow .octicon-briefcase"
    assert_accessible
    capture_screens("notifications-go-bag-use-by")
    click_on "Bottled water in Family go bag: use by #{water.use_by.strftime("%B %-d")}"

    assert_current_path edit_household_go_bag_item_path(household_id: households(:home), go_bag_id: go_bags(:family), id: water)
    assert_field "Name", with: "Bottled water"
  end

  test "go bag use-by dates: a child doesn't see the kind in Settings → Notifications" do
    sign_in identities(:eli)

    visit household_settings_notifications_url(household_id: households(:home))

    assert_selector "legend", text: "Weekly preview"
    assert_no_selector "legend", text: "Go bag use-by dates"
  end

  private
    def share_a_few_with_hannah
      travel_to(2.days.ago) { goals(:spouse_bible_reading).share_with(households(:home)) }
      users(:spouse).start_meeting_note(kind: "weekend", week_of: Date.new(2026, 11, 9)).share_with(households(:home))
      users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16)).share_with(households(:home))
      users(:head).notifications.where(subject: goals(:spouse_bible_reading)).sole.read
    end
end
