require "application_system_test_case"

class AccountRecoveryTest < ApplicationSystemTestCase
  # System tests don't clear the test mailer's deliveries between tests.
  setup { ActionMailer::Base.deliveries.clear }

  test "forgot your password renders, passes assert_accessible and sends reset instructions" do
    visit new_identity_password_url

    assert_selector "main h1", text: "Forgot your password?"
    assert_accessible
    capture_screens("forgot-password")
    request_password_reset_for "spouse@example.com"

    assert_text "You will receive an email with instructions on how to reset your password in a few minutes."
    assert_accessible
    capture_screens("forgot-password-sent")
  end

  test "requesting a reset email, opening its link and setting a new password lets the person sign in with it" do
    visit new_identity_password_url
    request_password_reset_for "spouse@example.com"
    assert_text "You will receive an email with instructions on how to reset your password in a few minutes."
    visit_link_in_email_to "spouse@example.com"

    assert_selector "main h1", text: "Change your password"
    assert_accessible
    capture_screens("change-password")
    fill_in "New password", with: "a-brand-new-secret"
    fill_in "Confirm new password", with: "a-brand-new-secret"
    click_on "Change my password"

    assert_text "Your password has been changed successfully. You are now signed in."
    assert_title "Home · The Head Family · Aglowy"
    assert_accessible
    capture_screens("change-password-changed")
    click_on "Sign out"

    assert_text "Signed out successfully."
    visit new_identity_session_url
    fill_in "Email", with: "spouse@example.com"
    fill_in "Password", with: "a-brand-new-secret"
    click_on "Sign in"
    assert_title "Home · The Head Family · Aglowy"
  end

  test "resend confirmation instructions renders, passes assert_accessible and sends them" do
    visit new_identity_confirmation_url

    assert_selector "main h1", text: "Resend confirmation instructions"
    assert_accessible
    capture_screens("resend-confirmation")
    fill_in "Email", with: "newcomer@example.com"
    click_on "Resend confirmation instructions"

    assert_text "You will receive an email with instructions for how to confirm your email address in a few minutes."
    assert_accessible
    capture_screens("resend-confirmation-sent")
    assert_equal "Confirmation instructions", last_email_to("newcomer@example.com").subject
  end

  test "resend unlock instructions renders, passes assert_accessible and sends them" do
    identities(:spouse).lock_access!(send_instructions: false)
    visit new_identity_unlock_url

    assert_selector "main h1", text: "Resend unlock instructions"
    assert_accessible
    capture_screens("resend-unlock")
    fill_in "Email", with: "spouse@example.com"
    click_on "Resend unlock instructions"

    assert_text "You will receive an email with instructions for how to unlock your account in a few minutes."
    assert_accessible
    capture_screens("resend-unlock-sent")
    assert_equal "Unlock instructions", last_email_to("spouse@example.com").subject
  end

  private
    def request_password_reset_for(email)
      fill_in "Email", with: email
      click_on "Send me password reset instructions"
    end

    def last_email_to(address)
      ActionMailer::Base.deliveries.reverse.find { it.to == [ address ] }
    end

    # The test mailer's links point at example.com, so visit the path on this server.
    def visit_link_in_email_to(address)
      visit URI(last_email_to(address).body.to_s[/href="([^"]+)"/, 1]).request_uri
    end
end
