require "application_system_test_case"

class ChildLoginTest < ApplicationSystemTestCase
  test "a head gives Sofia a login, Sofia chooses a password on her own device, then signs in with her username" do
    sign_in identities(:head)
    visit household_members_url(household_id: households(:home))

    within("#members .Box-row", text: "Sofia Child") { click_on "Give a login" }

    assert_selector "h1", text: "Give Sofia a login"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Members"
    assert_accessible
    capture_screens("child-login")

    fill_in "Username", with: "sofia.rivera"
    click_on "Create login"

    assert_text "Sofia's login is ready. The username is sofia.rivera."
    assert_selector "h2", text: "Open this link on Sofia's device"
    click_on "Copy link"
    # Headless Chrome may refuse the clipboard; then the link is selected for copying by hand.
    assert_selector "[role=status]", text: /\A(Link copied\.|The link is selected\. Copy it from there\.)\z/, visible: :all
    assert_accessible
    capture_screens("child-login-link")
    link = find_field("Password link", readonly: true).value

    Capybara.using_session(:sofias_device) do
      visit link

      assert_selector "h1", text: "Hi Sofia! Choose your password"
      assert_text "sofia.rivera"
      assert_accessible
      capture_screens("child-password")

      fill_in "Password", with: "sofia-picks-this"
      fill_in "Type it again", with: "sofia-picks-this"
      click_on "Save password and sign in"

      assert_text "Your password is saved."
      assert_title "Home · The Head Family · Aglowy"

      click_on "Sign out"
      fill_in "Email or username", with: "sofia.rivera"
      fill_in "Password", with: "sofia-picks-this"
      click_on "Sign in"

      assert_title "Home · The Head Family · Aglowy"
    end
  end

  test "an adult makes a new password link for Eli from the Members page" do
    sign_in identities(:spouse)
    visit household_members_url(household_id: households(:home))

    within("#members .Box-row", text: "Eli Child") do
      assert_text "Signs in as eli.rivera"
      click_on "New password link"
    end

    assert_selector "h1", text: "New password link for Eli"
    assert_text "A new password link for Eli is ready. The username is eli.rivera."
    assert_accessible
    capture_screens("child-password-link")
  end
end
