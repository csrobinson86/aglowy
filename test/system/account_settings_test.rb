require "application_system_test_case"

class AccountSettingsTest < ApplicationSystemTestCase
  # System tests don't clear the test mailer's deliveries between tests.
  setup { ActionMailer::Base.deliveries.clear }

  test "from the sidebar, a head changes their name, then their email, and sees the Banner" do
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))

    click_on "Hannah Head"

    assert_selector "h1", text: "Account settings"
    assert_link "Back to The Head Family"

    fill_in "Name", with: "Hannah Rivera"
    select "(GMT-06:00) Central Time (US & Canada)", from: "Your time zone"
    click_on "Save profile"

    assert_text "Your profile is saved."
    assert_field "Name", with: "Hannah Rivera"

    fill_in "Email", with: "hannah@example.com"
    fill_in "Current password", with: "password123"
    click_on "Save sign-in details"

    assert_text "Your sign-in details are saved."
    assert_selector ".Banner", text: "We sent a link to hannah@example.com. Your email changes once you open it. Until then, keep signing in with head@example.com."
    assert_field "Email", with: "head@example.com"
    assert_accessible
    capture_screens("account")

    click_on "Back to The Head Family"
    assert_title "Home · The Head Family · Aglowy"
  end

  test "a child with a username sees it read-only and only the password fields" do
    sign_in identities(:eli)
    visit edit_account_url

    assert_text "eli.rivera"
    assert_no_field "Email"
    assert_field "New password"
    assert_link "Back to your households"
    assert_accessible
    capture_screens("account-child")
  end

  test "choosing Dark changes every page" do
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))
    assert_selector "body[data-color-mode=auto]"

    click_on "Hannah Head"
    assert_checked_field "Match my device"
    choose "Dark"
    click_on "Save appearance"

    assert_text "Your appearance is saved."
    assert_selector "body[data-color-mode=dark]"
    assert_checked_field "Dark"
    assert_accessible
    capture_screens("account-settings-dark")

    click_on "Back to The Head Family"
    assert_title "Home · The Head Family · Aglowy"
    assert_selector "body[data-color-mode=dark]"
  end

  test "account settings with the Appearance section passes assert_accessible" do
    sign_in identities(:head)
    visit edit_account_url(return_to: households(:home).id)

    within ".Box", text: "Appearance" do
      assert_selector "h2", text: "Appearance"
      assert_selector "fieldset legend", text: "Theme"
      assert_checked_field "Match my device"
      assert_text "Light or dark, following your phone or computer's setting."
      assert_field "Light", type: "radio"
      assert_text "Always light, whatever your device is set to."
      assert_field "Dark", type: "radio"
      assert_text "Always dark. Easier on the eyes in the evening and at meetings."
      assert_button "Save appearance"
    end
    assert_selector "body[data-color-mode=auto]"
    assert_accessible
    capture_screens("account-settings")
  end
end
