require "application_system_test_case"

class HouseholdSwitchingTest < ApplicationSystemTestCase
  test "the two-household person lands on the chooser, opens one, switches to the other" do
    visit new_identity_session_url
    fill_in "Email or username", with: identities(:head).email
    fill_in "Password", with: "password123"
    click_on "Sign in"
    assert_selector "h1", text: "Your households"

    within("main") { click_on "The Head Family" }
    assert_title "Home · The Head Family · Aglowy"
    assert_turbo_idle

    open_household_switcher
    click_on "The Grandparent Family"
    assert_title "Home · The Grandparent Family · Aglowy"
  end

  test "switch households from the sidebar menu" do
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))
    assert_turbo_idle

    open_household_switcher
    assert_equal [ "The Grandparent Family Adult", "The Head Family Head" ], all("aside action-menu [role=menu] li").map { it.text.squish }
    within("aside action-menu") do
      assert_selector "a[aria-checked='true']", text: "The Head Family"
      assert_no_text "New household"
      click_on "The Grandparent Family"
    end

    assert_title "Home · The Grandparent Family · Aglowy"
    assert_current_path household_root_path(household_id: households(:parents))
    assert_selector "aside button", text: /The Grandparent Family\s*Adult/
  end

  test "going Back after switching still checks the household on the page" do
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))
    assert_turbo_idle

    open_household_switcher
    click_on "The Grandparent Family"
    assert_title "Home · The Grandparent Family · Aglowy"
    assert_turbo_idle

    page.go_back
    assert_title "Home · The Head Family · Aglowy"
    assert_turbo_idle

    open_household_switcher
    assert_selector "action-menu a[aria-checked='true']", count: 1
    assert_selector "action-menu a[aria-checked='true']", text: "The Head Family"
  end

  test "the open switcher passes assert_accessible" do
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))
    assert_turbo_idle

    open_household_switcher
    assert_accessible
    capture_screens("switcher-open")
  end

  test "a child's open switcher passes assert_accessible" do
    Membership.create!(user: users(:eli), household: households(:parents), role: :child)
    sign_in identities(:eli)
    visit household_root_url(household_id: households(:home))
    assert_turbo_idle

    open_household_switcher
    assert_selector "action-menu a[aria-checked='true']", text: "The Head Family"
    assert_accessible
    capture_screens("switcher-open-child")
  end

  test "a person with one household has no switcher menu to open" do
    sign_in identities(:spouse)
    visit household_root_url(household_id: households(:home))
    assert_turbo_idle

    within("aside") do
      assert_text(/The Head Family\s*Adult/)
      assert_no_selector "action-menu"
      assert_no_selector "button[aria-haspopup='true']"
    end
    assert_accessible
    capture_screens("switcher-one-household")
  end

  test "every page on the way passes assert_accessible" do
    sign_in identities(:head)

    {
      "households" => households_url,
      "new-household" => new_household_url,
      "dashboard" => household_root_url(household_id: households(:home)),
      "dashboard-second-household" => household_root_url(household_id: households(:parents))
    }.each do |name, url|
      visit url
      assert_selector "h1"
      assert_accessible
      capture_screens(name)
    end
  end

  private
    def open_household_switcher
      find("aside button[aria-haspopup='true']").click
      assert_selector "action-menu [role='menu']", visible: true
    end
end
