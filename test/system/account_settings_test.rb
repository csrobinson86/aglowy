require "application_system_test_case"

# /account, for a person with no household (docs/design/settings.md, /account stays). Everyone else has Settings.
class AccountSettingsTest < ApplicationSystemTestCase
  # System tests don't clear the test mailer's deliveries between tests.
  setup { ActionMailer::Base.deliveries.clear }

  test "a person with no household changes their name, then their email, and sees the Banner" do
    sign_in identities(:former)
    visit edit_account_url

    assert_selector "h1", text: "Account settings"
    assert_no_link "Back to your households"

    fill_in "Name", with: "Frances Rivera"
    select "(GMT-06:00) Central Time (US & Canada)", from: "Your time zone"
    click_on "Save profile"

    assert_text "Your profile is saved."
    assert_field "Name", with: "Frances Rivera"

    fill_in "Email", with: "frances@example.com"
    fill_in "Current password", with: "password123"
    click_on "Save sign-in details"

    assert_text "Your sign-in details are saved."
    assert_selector ".Banner", text: "We sent a link to frances@example.com. Your email changes once you open it. Until then, keep signing in with former@example.com."
    assert_field "Email", with: "former@example.com"
    assert_accessible
    capture_screens("account")
  end

  test "choosing Dark turns the page dark" do
    sign_in identities(:former)
    visit edit_account_url
    assert_selector "body[data-color-mode=auto]"

    within ".Box", text: "Appearance" do
      assert_selector "h2", text: "Appearance"
      assert_selector "fieldset legend", text: "Theme"
      assert_checked_field "Match my device"
    end
    assert_accessible
    capture_screens("account-settings")

    choose "Dark"
    click_on "Save appearance"

    assert_text "Your appearance is saved."
    assert_selector "body[data-color-mode=dark]"
    assert_checked_field "Dark"
    assert_accessible
    capture_screens("account-settings-dark")
  end

  test "a person with no household, allowed to start one, sees \"New household\" in My households" do
    assert users(:former).can_start_household?
    sign_in identities(:former)
    visit edit_account_url

    within(".Box", text: "My households") do
      assert_selector ".Box-header h2", text: "My households"
      within(".Box-header") { click_on "New household" }
    end
    assert_selector "h1", text: "New household"
  end

  test "with a household, /account opens Settings" do
    sign_in identities(:spouse)
    visit edit_account_url

    assert_selector "h1", text: "Settings"
    assert_selector "h2", text: "Profile"
    assert_title "Profile · Settings · The Head Family · Aglowy"
  end
end
