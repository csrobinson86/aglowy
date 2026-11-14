require "application_system_test_case"

class FocusedLayoutTest < ApplicationSystemTestCase
  test "sign in passes assert_accessible" do
    visit new_identity_session_url

    assert_focused_page "Sign in to Aglowy"
    capture_screens("focused-sign-in")
  end

  test "sign up passes assert_accessible" do
    visit new_signup_url

    assert_focused_page "Create your account"
  end

  test "the chooser passes assert_accessible" do
    sign_in identities(:head)
    visit households_url

    assert_focused_page "Your households"
    capture_screens("focused-households")
  end

  test "new household passes assert_accessible" do
    sign_in identities(:head)
    visit new_household_url

    assert_focused_page "New household"
  end

  private
    # The Aglowy mark in the header, one h1 in main, and no sidebar.
    def assert_focused_page(title)
      assert_selector "header a[href='/'] svg.octicon-sun"
      assert_selector "h1", count: 1
      assert_selector "main h1", text: title
      assert_no_selector "aside"
      assert_accessible
    end
end
