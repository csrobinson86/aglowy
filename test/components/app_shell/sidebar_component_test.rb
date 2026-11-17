require "test_helper"

class AppShell::SidebarComponentTest < ViewComponent::TestCase
  test "Today's meeting shows for a head, an adult and a child, first in the Mine group with the sun icon" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      render_inline(AppShell::SidebarComponent.new(membership: memberships(membership), selected_item: :dashboards, label: "Main"))

      assert_equal [ "Today's meeting", "Personal study", "Notes", "My goals" ], page.all("nav[aria-label='Main'] a").map { it.text.strip }.last(4), "for #{membership}"
      assert_selector "nav[aria-label='Main'] a[href='/#{households(:home).id}/todays_meeting'] svg.octicon-sun"
    end
  end

  test "there's no Meeting notes item: meeting notes are a tab in Notes" do
    render_inline(AppShell::SidebarComponent.new(membership: memberships(:head_in_home), selected_item: :dashboards, label: "Main"))

    assert_selector "nav[aria-label='Main'] h2", text: "Mine"
    assert_no_selector "nav[aria-label='Main'] a", text: "Meeting notes"
    assert_no_selector "nav[aria-label='Main'] a[href='/#{households(:home).id}/meeting_notes']"
  end

  test "Notes is selected on the notes pages, the meeting notes list and a meeting note, and the shared list" do
    %i[ personal_notes meeting_notes shared_meeting_notes ].each do |selected_item|
      render_inline(AppShell::SidebarComponent.new(membership: memberships(:head_in_home), selected_item:, label: "Main"))

      assert_selector "nav[aria-label='Main'] a[aria-current='page'][href='/#{households(:home).id}/notes']", text: "Notes", count: 1
      assert_selector "nav[aria-label='Main'] a[aria-current='page']", count: 1
    end
  end

  test "Today's meeting is the current item on its page" do
    render_inline(AppShell::SidebarComponent.new(membership: memberships(:spouse_in_home), selected_item: :todays_meetings, label: "Main"))

    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Today's meeting"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", count: 1
  end

  test "Settings shows in the footer for a head, an adult and a child, with the gear icon, opening Settings" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      render_inline(AppShell::SidebarComponent.new(membership: memberships(membership), selected_item: :dashboards, label: "Main"))

      assert_selector "nav[aria-label='Main settings'] a[href='/#{households(:home).id}/settings'] svg.octicon-gear", count: 1
      assert_selector "nav[aria-label='Main settings'] a", text: "Settings", count: 1
      assert_no_selector "nav[aria-label='Main settings'] a[aria-current=page]"
    end
  end

  test "Settings is selected on every settings page" do
    render_inline(AppShell::SidebarComponent.new(membership: memberships(:child_in_home), selected_item: :settings, label: "Main"))

    assert_selector "nav[aria-label='Main settings'] a[aria-current=page]", text: "Settings"
    assert_no_selector "nav[aria-label='Main'] a[aria-current=page]"
  end

  test "the person's name is plain text, not a link" do
    render_inline(AppShell::SidebarComponent.new(membership: memberships(:head_in_home), selected_item: :dashboards, label: "Main"))

    assert_text "Hannah Head"
    assert_no_link "Hannah Head"
    assert_no_selector "a[href^='/account']"
  end

  test "Notifications sits above Settings in the footer, with the bell, for a head, an adult and a child" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      render_inline(AppShell::SidebarComponent.new(membership: memberships(membership), selected_item: :dashboards, label: "Main"))

      assert_equal [ "Notifications", "Settings" ], page.all("nav[aria-label='Main settings'] a .ActionListItem-label").map { it.text.strip }, "for #{membership}"
      assert_selector "nav[aria-label='Main settings'] a[href='/#{households(:home).id}/notifications'] svg.octicon-bell"
    end
  end

  test "with none unread, the counter is hidden and the accessible name is just Notifications" do
    render_inline(AppShell::SidebarComponent.new(membership: memberships(:spouse_in_home), selected_item: :dashboards, label: "Main"))

    assert_selector "a[href='/#{households(:home).id}/notifications'] .ActionListItem-label", exact_text: "Notifications", normalize_ws: true
    assert_selector "a[href='/#{households(:home).id}/notifications'] .Counter[hidden][aria-hidden='true']", visible: :all
  end

  test "with three unread, the counter shows 3 and the accessible name says so" do
    notify(users(:spouse), 3)

    render_inline(AppShell::SidebarComponent.new(membership: memberships(:spouse_in_home), selected_item: :dashboards, label: "Main"))

    assert_selector "a[href='/#{households(:home).id}/notifications'] .ActionListItem-label", exact_text: "Notifications, 3 unread", normalize_ws: true
    assert_selector "a[href='/#{households(:home).id}/notifications'] .ActionListItem-label .sr-only", exact_text: ", 3 unread"
    assert_selector "a[href='/#{households(:home).id}/notifications'] .Counter[aria-hidden='true']:not([hidden])", text: "3"
  end

  test "past 99 the counter shows 99+" do
    notify(users(:spouse), 100)

    render_inline(AppShell::SidebarComponent.new(membership: memberships(:spouse_in_home), selected_item: :dashboards, label: "Main"))

    assert_selector "a[href='/#{households(:home).id}/notifications'] .Counter", text: "99+"
    assert_selector "a[href='/#{households(:home).id}/notifications'] .ActionListItem-label", exact_text: "Notifications, 100 unread", normalize_ws: true
  end

  test "Notifications is selected on the inbox" do
    render_inline(AppShell::SidebarComponent.new(membership: memberships(:child_in_home), selected_item: :notifications, label: "Main"))

    assert_selector "nav[aria-label='Main settings'] a[aria-current=page]", text: "Notifications"
    assert_selector "a[aria-current=page]", count: 1
  end

  private
    # Notifications made straight in the table: the count is all the sidebar reads.
    def notify(user, count)
      Notification.insert_all(Array.new(count) do |n|
        { user_id: user.id, household_id: households(:home).id, kind: "shared_with_you", subject_type: "MeetingNote",
          subject_id: meeting_notes(:head_midweek).id, actor_id: users(:head).id, dedupe_key: "shared_with_you:#{n}" }
      end)
    end
end
