require "application_system_test_case"

class SignUpTest < ApplicationSystemTestCase
  test "a visitor signs up, confirms, signs in and lands on the new household" do
    visit new_identity_session_url
    assert_accessible
    capture_screens("sign-in")
    click_on "Sign up"

    assert_selector "h1", text: "Sign up"
    assert_accessible
    capture_screens("sign-up")
    fill_in "Your name", with: "Rosa Robinson"
    fill_in "Email", with: "rosa@example.com"
    fill_in "Password", with: "password123"
    fill_in "Household name", with: "The Robinson Family"
    select "(GMT+00:00) London", from: "Time zone"
    click_on "Sign up"

    assert_text "Check your email to confirm your account."
    assert_accessible
    capture_screens("sign-in-check-email")

    # The test mailer's links point at example.com, so visit the path on this server.
    email = ActionMailer::Base.deliveries.find { it.to == [ "rosa@example.com" ] }
    visit URI(email.body.to_s[/href="([^"]+)"/, 1]).request_uri

    assert_text "Your email address has been successfully confirmed."
    assert_accessible
    fill_in "Email", with: "rosa@example.com"
    fill_in "Password", with: "password123"
    click_on "Log in"

    assert_title "Home · The Robinson Family · Aglowy"
    assert_accessible
    capture_screens("dashboard-new-household")
  end
end
