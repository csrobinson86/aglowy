require "application_system_test_case"

class MemberRolesTest < ApplicationSystemTestCase
  setup { sign_in identities(:head) }

  test "a head changes a role, then removes a member through the dialog" do
    visit edit_household_settings_url(household_id: households(:home))

    within_members_and_roles do
      assert_text "Hannah Head"
      assert_text "A household always keeps at least one head."
      assert_no_text "Frances Former"
    end
    capture_screens("household-settings-members", scroll_to: "#members-and-roles")

    select "Head", from: "Sam Spouse"

    assert_text "Sam Spouse is now a head."
    assert_select "Sam Spouse", selected: "Head"
    assert memberships(:spouse_in_home).reload.head?

    find("button[aria-label='Remove Charlie Child']").click

    within "dialog[open]" do
      assert_text "Remove Charlie Child from the The Head Family?"
      assert_text "Removing someone works like them leaving."
      assert_text "Their own notes and goals stay with them."
    end
    assert_accessible
    capture_screens("remove-member")

    within("dialog[open]") { click_on "Remove" }

    assert_text "Charlie Child was removed from the household."
    within_members_and_roles { assert_no_text "Charlie Child" }
    assert_not memberships(:child_in_home).reload.active?
  end

  test "the last head making themselves an adult sees why on their row" do
    visit edit_household_settings_url(household_id: households(:home))

    select "Adult", from: "Hannah Head"

    within_members_and_roles { assert_text "A household needs at least one active head" }
    assert_select "Hannah Head", selected: "Head"
    assert_accessible
    capture_screens("member-role-refused", scroll_to: "#members-and-roles")
  end

  private
    def within_members_and_roles(&)
      within("#members-and-roles", &)
    end
end
