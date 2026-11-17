require "application_system_test_case"

# Settings on a phone (docs/design/settings.md, On a phone; frames phone-settings.png and phone-settings-menu.png): the
# section nav becomes a menu button above the section, named after it.
class SettingsPhoneTest < ApplicationSystemTestCase
  setup do
    sign_in identities(:head)
    visit root_url
    emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
    emulate_touch(true)
  end

  teardown do
    cdp("Emulation.clearDeviceMetricsOverride")
    cdp("Emulation.setTouchEmulationEnabled", enabled: false)
  end

  test "pick Appearance from the menu" do
    visit household_settings_profile_url(household_id: households(:home))

    assert_no_selector "nav[aria-label='Settings']"
    menu_button = find_button("Profile")
    assert_operator menu_button.evaluate_script("this.offsetHeight"), :>=, 44, "the menu button is too small to tap"

    menu_button.click
    all("[role=menuitemradio]").each do |item|
      assert_operator item.evaluate_script("this.offsetHeight"), :>=, 44, "#{item.text} is too small to tap"
    end
    find("[role=menuitemradio]", text: "Appearance").click

    assert_button "Appearance"
    assert_text "Follows you to every household and device."
    assert_field "Dark", type: "radio"
    assert_equal evaluate_script("document.documentElement.clientWidth"), evaluate_script("document.documentElement.scrollWidth"), "the page is wider than the phone"
    assert_accessible
    capture_screens("phone-settings", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))

    # capture_screens puts the desktop size back.
    emulate_viewport(*ScreenshotHelper::VIEWPORTS[:phone], phone: true)
    emulate_touch(true)
    click_on "Appearance"
    assert_selector "[role=menuitemradio][aria-checked=true]", text: "Appearance"
    assert_accessible
    capture_screens("phone-settings-menu", viewports: ScreenshotHelper::VIEWPORTS.slice(:phone))
  end
end
