require "application_system_test_case"

# Below md the sidebar gives way to a top bar and a left-side menu (docs/design/app-shell.md, Phone).
class PhoneMenuTest < ApplicationSystemTestCase
  setup do
    sign_in identities(:head)
    emulate_viewport(390, 844, phone: true)
    visit household_root_url(household_id: households(:home))
    assert_turbo_idle
  end

  teardown do
    cdp("Emulation.clearDeviceMetricsOverride")
    cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  end

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

  test "the top bar: the menu button, the mark beside it, and the bell at the end, each a touch target" do
    emulate_touch(true)
    visit household_members_url(household_id: households(:home))
    assert_selector "h1", text: "Members"
    assert_turbo_idle

    bar, logo = find("header.app-shell__top-bar"), find("header.app-shell__top-bar a:has(img[alt='Aglowy'])")
    # var(--base-size-4) between the menu button and the mark, give or take 2px.
    assert_includes 0..(4 + 2), logo.rect.x - right_edge(menu_button)
    assert_in_delta centre_y(bar), centre_y(logo), 2
    assert_operator right_edge(bar) - right_edge(bell), :<=, padding_right(bar)
    [ menu_button, logo, bell ].each { assert_touch_target it }
    assert_operator menu_button.rect.x, :<, logo.rect.x
    assert_operator logo.rect.x, :<, bell.rect.x

    logo.click
    assert_selector "h1", text: "Home"
    assert_current_path household_root_path(household_id: households(:home))
    assert_accessible
    capture_screens("phone-top-bar")
  end

  test "the household switcher is in the open menu, not the top bar" do
    within("header.app-shell__top-bar") do
      assert_no_selector "action-menu", visible: :all
      assert_no_text "The Head Family"
    end

    open_menu
    within("dialog[open]") { find("button[aria-haspopup='true']", text: "The Head Family").click }
    within("dialog[open] action-menu [role='menu']") { click_on "The Grandparent Family" }

    assert_title "Home · The Grandparent Family · Aglowy"
    assert_current_path household_root_path(household_id: households(:parents))
  end

  private
    def bell
      find("header.app-shell__top-bar a[href='#{household_notifications_path(household_id: households(:home))}']")
    end

    def centre_y(element) = element.rect.y + element.rect.height / 2.0
    def right_edge(element) = element.rect.x + element.rect.width
    def padding_right(element) = evaluate_script("getComputedStyle(arguments[0]).paddingRight", element).to_f

    # Primer's IconButton takes its name from a label tooltip (aria-labelledby).
    def menu_button
      find(:xpath, "//button[@aria-labelledby = //tool-tip[normalize-space() = 'Open menu']/@id]")
    end

    def open_menu
      menu_button.click
      assert_selector "dialog[open] nav[aria-label='Menu']"
    end
end
