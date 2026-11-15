require "application_system_test_case"

class AddMemberTest < ApplicationSystemTestCase
  test "a head adds a child and sees them in the member list" do
    sign_in identities(:head)
    visit household_members_url(household_id: households(:home))

    click_on "Add without a login"
    assert_selector "h1", text: "Add a member"
    assert_accessible
    capture_screens("new-member")

    fill_in "Name", with: "Baby Head"
    select "Child", from: "Role"
    click_on "Add member"

    assert_text "Baby Head was added to the household."
    within("main") { assert_text(/Baby Head\s*No login\s*Child/) }
    assert_accessible
    capture_screens("members-member-added")
  end

  test "an adult sees Invite by email and Add without a login" do
    sign_in identities(:spouse)
    visit household_members_url(household_id: households(:home))

    assert_selector "h1", text: "Members"
    assert_link "Invite by email"
    assert_link "Add without a login"
    assert_accessible
    capture_screens("members-adult")
  end
end
