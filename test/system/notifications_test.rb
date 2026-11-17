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
    assert_link "Notifications", exact: true

    note.share_with(households(:home))

    assert_link "Notifications, 1 unread"
    assert_selector "nav[aria-label='Main settings'] .Counter", text: "1"

    click_on "Notifications, 1 unread"
    assert_selector "h1", text: "Notifications"
    click_on "Sam shared a meeting note"

    assert_current_path household_meeting_note_path(household_id: households(:home), id: note)
    assert_text "Shared by Sam Spouse"
    assert_link "Notifications", exact: true
    assert_no_selector "nav[aria-label='Main settings'] .Counter", visible: true
  end

  test "Mark all as read clears the list's unread dots and the counter" do
    share_a_few_with_hannah
    sign_in identities(:head)
    visit household_notifications_url(household_id: households(:home))

    click_on "Unread (2)"
    assert_selector "main .Box-row", count: 2
    click_on "Mark all as read"

    assert_text "You're all caught up"
    assert_link "Notifications", exact: true
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

    users(:head).update!(appearance: "light")
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

  private
    def share_a_few_with_hannah
      travel_to(2.days.ago) { goals(:spouse_bible_reading).share_with(households(:home)) }
      users(:spouse).start_meeting_note(kind: "weekend", week_of: Date.new(2026, 11, 9)).share_with(households(:home))
      users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16)).share_with(households(:home))
      users(:head).notifications.where(subject: goals(:spouse_bible_reading)).sole.read
    end
end
