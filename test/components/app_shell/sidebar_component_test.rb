require "test_helper"

class AppShell::SidebarComponentTest < ViewComponent::TestCase
  test "Today's meeting shows for a head, an adult and a child, first in the Mine group with the sun icon" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      render_inline(AppShell::SidebarComponent.new(membership: memberships(membership), selected_item: :dashboards, label: "Main"))

      assert_equal [ "Today's meeting", "Meeting notes", "Personal study", "Notes", "My goals" ], page.all("nav[aria-label='Main'] a").map { it.text.strip }.last(5), "for #{membership}"
      assert_selector "nav[aria-label='Main'] a[href='/#{households(:home).id}/todays_meeting'] svg.octicon-sun"
    end
  end

  test "Today's meeting is the current item on its page" do
    render_inline(AppShell::SidebarComponent.new(membership: memberships(:spouse_in_home), selected_item: :todays_meetings, label: "Main"))

    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Today's meeting"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", count: 1
  end
end
