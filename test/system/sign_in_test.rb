require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  test "sign in from / and land in the household" do
    visit root_url
    fill_in "Email", with: identities(:spouse).email
    fill_in "Password", with: "password123"
    click_on "Sign in"

    assert_title "Home · The Head Family · Aglowy"
    assert_current_path household_root_path(household_id: households(:home))
  end

  test "a wrong password shows Devise's alert on the sign-in page" do
    visit root_url
    fill_in "Email", with: identities(:spouse).email
    fill_in "Password", with: "wrong-password"
    click_on "Sign in"

    assert_text "Invalid email or password."
    assert_selector "h1", text: "Sign in to Aglowy"
    assert_accessible
  end

  test "Create an account opens sign-up" do
    visit root_url
    click_on "Create an account"

    assert_current_path new_signup_path
    assert_selector "h1", text: "Create your account"
    click_on "Sign in"

    assert_current_path root_path
  end

  test "the sign-in page passes assert_accessible" do
    visit root_url

    assert_selector "h1", text: "Sign in to Aglowy"
    assert_accessible
    capture_screens("sign-in")
  end

  test "the sign-up page passes assert_accessible" do
    visit new_signup_url

    assert_selector "h1", text: "Create your account"
    assert_text "You'll be the head of your household."
    assert_text "Only your family sees it."
    assert_text "We'll send you an email to confirm your address before you can sign in."
    assert_accessible
    capture_screens("sign-up")
  end
end
