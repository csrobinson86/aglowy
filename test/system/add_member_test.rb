require "application_system_test_case"

class AddMemberTest < ApplicationSystemTestCase
  test "a head adds a child and sees them in the member list" do
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))

    click_on "Add a member"
    assert_selector "h1", text: "Add a member"
    assert_accessible
    capture_screens("new-member")

    fill_in "Name", with: "Baby Head"
    select "Child", from: "Role"
    click_on "Add member"

    assert_text "Baby Head was added to the household."
    within("main") { assert_text(/Baby Head\s*Child/) }
    assert_accessible
    capture_screens("dashboard-member-added")
  end

  test "an adult doesn't see the link to add a member" do
    sign_in identities(:spouse)
    visit household_root_url(household_id: households(:home))

    assert_selector "h1", text: "The Head Family"
    assert_no_link "Add a member"
    capture_screens("dashboard-adult")
  end
end
