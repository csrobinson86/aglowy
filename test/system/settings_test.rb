require "application_system_test_case"

# Settings, a page per section, starting with the person's own (docs/design/settings.md; frames settings-profile.png,
# settings-child.png and settings-appearance-dark.png).
class SettingsTest < ApplicationSystemTestCase
  test "a head opens Settings from the sidebar, changes their name, picks Dark and changes their password" do
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))

    within("aside") { click_on "Settings" }

    assert_selector "h1", text: "Settings"
    assert_selector "h2", text: "Profile"
    assert_selector "nav[aria-label='Settings'] a[aria-current=page]", text: "Profile"
    assert_selector "aside nav a[aria-current=page]", text: "Settings"
    assert_accessible
    capture_screens("settings-profile")

    fill_in "Name", with: "Hannah Rivera"
    click_on "Save profile"
    assert_text "Your profile is saved."
    assert_field "Name", with: "Hannah Rivera"
    within("aside") { assert_text "Hannah Rivera" }

    within("nav[aria-label='Settings']") { click_on "Appearance" }
    pick_dark

    within("nav[aria-label='Settings']") { click_on "Signing in" }
    fill_in "New password", with: "new-password-1"
    fill_in "Current password", with: "password123"
    click_on "Save sign-in details"
    assert_text "Your sign-in details are saved."
    assert_selector "h2", text: "Signing in"
    assert identities(:head).reload.valid_password?("new-password-1")
  end

  test "a child opens Settings, sees only their own sections, changes their name, picks Dark and changes their password" do
    sign_in identities(:eli)
    visit household_root_url(household_id: households(:home))

    within("aside") { click_on "Settings" }
    fill_in "Name", with: "Eli Rivera"
    click_on "Save profile"
    assert_text "Your profile is saved."

    within("nav[aria-label='Settings']") { click_on "Appearance" }
    assert_selector "nav[aria-label='Settings'] a[aria-current=page]", text: "Appearance"
    assert_equal [ "Profile", "Appearance", "Signing in", "My households" ], all("nav[aria-label='Settings'] a").map(&:text)
    assert_accessible
    capture_screens("settings-child")

    pick_dark

    within("nav[aria-label='Settings']") { click_on "Signing in" }
    assert_text "eli.rivera"
    assert_no_field "Email"
    fill_in "New password", with: "eli-new-pass"
    fill_in "Current password", with: "password123"
    click_on "Save sign-in details"
    assert_text "Your sign-in details are saved."
    assert identities(:eli).reload.valid_password?("eli-new-pass")
  end

  private
    def pick_dark
      assert_selector "h2", text: "Appearance"
      assert_selector "body[data-color-mode=auto]"
      choose "Dark"
      click_on "Save appearance"

      assert_text "Your appearance is saved."
      assert_selector "body[data-color-mode=dark]"
      assert_checked_field "Dark"
      assert_accessible
      capture_screens("settings-appearance-dark")
    end
end
