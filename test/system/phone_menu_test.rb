require "application_system_test_case"

# Below md the sidebar gives way to a top bar and a left-side menu (docs/design/app-shell.md, Phone).
class PhoneMenuTest < ApplicationSystemTestCase
  setup do
    sign_in identities(:head)
    emulate_viewport(390, 844, phone: true)
    visit household_root_url(household_id: households(:home))
    assert_turbo_idle
  end

  teardown { cdp("Emulation.clearDeviceMetricsOverride") }

  test "the sidebar isn't visible" do
    assert_selector "h1", text: "Home"
    assert_no_selector "aside"
    assert_no_selector "nav[aria-label='Main']"
    assert menu_button.visible?
  end

  test "Open menu opens the panel" do
    open_menu

    within("dialog[open]") do
      assert_selector "h1", text: "Menu"
      assert_selector "nav[aria-label='Menu'] a[aria-current='page']", text: "Home"
      assert_button "Sign out"
    end
  end

  test "a link in it navigates" do
    open_menu
    within("nav[aria-label='Menu']") { click_on "Members" }

    assert_selector "h1", text: "Members"
    assert_current_path household_members_path(household_id: households(:home))
    assert_no_selector "dialog[open]"
    assert_turbo_idle

    page.go_back
    assert_selector "h1", text: "Home"
    assert_turbo_idle
    assert_no_selector "dialog[open]", visible: :all
  end

  test "Escape closes it" do
    open_menu
    page.send_keys(:escape)

    assert_no_selector "dialog[open]"
    assert_no_selector "nav[aria-label='Menu']"
  end

  test "widening past md with the menu open keeps it showing, so the page isn't left inert" do
    open_menu
    cdp("Emulation.clearDeviceMetricsOverride")

    assert_selector "aside nav[aria-label='Main']"
    assert_selector "dialog[open] nav[aria-label='Menu']"
  end

  test "passes assert_accessible closed and open" do
    assert_accessible

    open_menu
    assert_accessible
    capture_screens("phone-menu")
  end

  private
    # Primer's IconButton takes its name from a label tooltip (aria-labelledby).
    def menu_button
      find(:xpath, "//button[@aria-labelledby = //tool-tip[normalize-space() = 'Open menu']/@id]")
    end

    def open_menu
      menu_button.click
      assert_selector "dialog[open] nav[aria-label='Menu']"
    end
end
