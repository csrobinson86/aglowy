require "application_system_test_case"

class AcceptInvitationExistingTest < ApplicationSystemTestCase
  setup do
    @invitation = invitations(:ana)
    @invitation.update_column(:email, identities(:outsider).email)
    @token = @invitation.generate_token_for(:acceptance)
  end

  test "someone with an account signs in from the invitation, joins and lands in the household" do
    visit invitation_acceptance_path(token: @token)
    click_on "Sign in to accept"

    fill_in "Email or username", with: identities(:outsider).email
    fill_in "Password", with: "password123"
    click_on "Sign in"

    assert_selector "h1", text: "Join the The Head Family?"
    assert_text "Signed in as outsider@example.com"
    assert_accessible
    capture_screens("accept-existing")

    click_on "Join household"

    assert_text "Welcome to the The Head Family."
    assert_title "Home · The Head Family · Aglowy"
    assert_accessible
  end

  test "declining goes to the households page" do
    sign_in identities(:outsider)
    visit invitation_acceptance_path(token: @token)

    click_on "Decline"

    assert_text "Invitation declined."
    assert_selector "h1", text: "Your households"
    assert_no_link "The Head Family"
    assert_accessible
  end

  test "someone signed in with a different email sees the invited address partly hidden and a Sign out button" do
    sign_in identities(:grandparent)
    visit invitation_acceptance_path(token: @token)

    assert_text "This invitation is for a different email address"
    assert_text "It was sent to o•••••@example.com, and you're signed in as grandparent@example.com."
    assert_no_text identities(:outsider).email
    assert_no_button "Join household"
    assert_button "Sign out"
    assert_accessible
    capture_screens("accept-wrong-email")

    click_on "Sign out"

    assert_selector "h1", text: "Sign in to Aglowy"
  end
end
