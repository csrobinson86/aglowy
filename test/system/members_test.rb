require "application_system_test_case"

class MembersTest < ApplicationSystemTestCase
  setup { sign_in identities(:head) }

  test "Members is selected on the member list, which passes assert_accessible" do
    visit household_root_url(household_id: households(:home))
    within("nav[aria-label='Main']") { click_on "Members" }

    assert_selector "h1", text: "Members"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Members"
    assert_accessible
    capture_screens("members")
  end

  test "Members stays selected on Add a member, which passes assert_accessible" do
    visit household_members_url(household_id: households(:home))
    click_on "Add a member"

    assert_selector "h1", text: "Add a member"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Members"
    within("nav[aria-label='Breadcrumb']") do
      assert_link "Members", href: household_members_path(household_id: households(:home))
      assert_selector "a[aria-current='page']", text: "Add a member"
    end
    assert_accessible
  end
end
