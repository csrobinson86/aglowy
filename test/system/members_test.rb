require "application_system_test_case"

class MembersTest < ApplicationSystemTestCase
  setup { sign_in identities(:head) }

  test "Members is selected on the member list, which passes assert_accessible" do
    visit household_root_url(household_id: households(:home))
    within("nav[aria-label='Main']") { click_on "Members" }

    assert_selector "h1", text: "Members"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Members"
    assert_accessible
  end

  test "Members stays selected on Add a member, which passes assert_accessible" do
    visit household_members_url(household_id: households(:home))
    click_on "Add without a login"

    assert_selector "h1", text: "Add a member"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Members"
    within("nav[aria-label='Breadcrumb']") do
      assert_link "Members", href: household_members_path(household_id: households(:home))
      assert_selector "a[aria-current='page']", text: "Add a member"
    end
    assert_accessible
  end

  test "a head invites someone, sees them under Invited, not joined yet, and cancels it" do
    visit household_members_url(household_id: households(:home))
    click_on "Invite by email"

    assert_selector "h1", text: "Invite someone to the The Head Family"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Members"
    assert_accessible
    capture_screens("invite")

    fill_in "Email", with: "rosa@example.com"
    choose "Head"
    click_on "Send invitation"

    assert_text "Invitation sent to rosa@example.com."
    within("#invitations") do
      assert_selector "h2", text: "Invited, not joined yet"
      assert_selector ".Box-row", text: /rosa@example.com\s*Invited by Hannah · until/
    end
    assert_accessible
    capture_screens("members")

    find("button[aria-label='Cancel the invitation to rosa@example.com']").click
    assert_text "Invitation to rosa@example.com cancelled."
    within("#invitations") { assert_no_text "rosa@example.com" }
  end
end
