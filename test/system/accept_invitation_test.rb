require "application_system_test_case"

class AcceptInvitationTest < ApplicationSystemTestCase
  include ActionMailer::TestHelper

  # System tests don't clear the test mailer's deliveries between tests.
  setup { ActionMailer::Base.deliveries.clear }

  test "someone new opens the link in the email, creates an account and lands on the household home signed in" do
    perform_enqueued_jobs { invitations(:ana).deliver_later }

    # The test mailer's links point at example.com, so visit the path on this server.
    email = ActionMailer::Base.deliveries.find { it.to == [ "ana.ortiz@example.com" ] }
    visit URI(CGI.unescapeHTML(email.html_part.body.to_s[/href="([^"]+)"/, 1])).request_uri

    assert_selector "h1", text: "Join the The Head Family"
    assert_field "Email", with: "ana.ortiz@example.com", readonly: true
    assert_accessible
    fill_in "Your name", with: "Ana Ortiz"
    capture_screens("accept-new")

    fill_in "Password", with: "password123"
    click_on "Create account and join"

    assert_text "Welcome to the The Head Family."
    assert_title "Home · The Head Family · Aglowy"
    assert_text "Ana Ortiz"
    assert_accessible
  end

  test "a link that can't be used says so, naming no household" do
    visit invitation_acceptance_path(token: "garbage")

    assert_selector "h1", text: "This invitation can't be used"
    assert_no_text "The Head Family"
    assert_accessible
    capture_screens("accept-invalid")
  end

  test "an invited address that already has a login is asked to sign in to accept" do
    identities(:newcomer).update_column(:email, invitations(:ana).email)

    visit invitation_acceptance_path(token: invitations(:ana).generate_token_for(:acceptance))

    assert_selector "h1", text: "Join the The Head Family"
    assert_link "Sign in to accept", href: new_identity_session_path
    assert_accessible
    capture_screens("accept-sign-in")
  end
end
