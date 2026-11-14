require "application_system_test_case"

class AppShellTest < ApplicationSystemTestCase
  setup do
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))
  end

  test "a member's household page shows the sidebar" do
    within "nav[aria-label='Main']" do
      assert_link "Home", href: household_root_path(household_id: households(:home))
      assert_selector "a[aria-current='page']", text: "Home"
    end
    assert_link "Aglowy", href: household_root_path(household_id: households(:home))
    assert_text "Hannah Head"
  end

  test "Sign out from the sidebar signs them out" do
    click_on "Sign out"

    assert_no_text "Hannah Head"
    visit household_root_url(household_id: households(:home))
    assert_current_path new_identity_session_path
  end

  test "the page passes assert_accessible" do
    assert_selector "h1", text: "Home"
    assert_accessible
    capture_screens("household-home")
  end
end
