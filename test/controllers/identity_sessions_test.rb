require "test_helper"

class IdentitySessionsTest < ActionDispatch::IntegrationTest
  test "a confirmed identity signs in with email and password" do
    sign_in_with identities(:head)

    assert_redirected_to root_path
    assert_equal "Signed in successfully.", flash[:notice]
  end

  test "an unconfirmed identity can't" do
    sign_in_with identities(:newcomer)

    assert_redirected_to new_identity_session_path
    assert_equal "You have to confirm your email address before continuing.", flash[:alert]
  end

  test "a locked identity can't" do
    identities(:spouse).lock_access!(send_instructions: false)

    sign_in_with identities(:spouse)

    assert_response :unprocessable_entity
    assert_includes response.body, "Your account is locked."
  end

  private

  def sign_in_with(identity)
    post identity_session_path, params: { identity: { email: identity.email, password: "password123" } }
  end
end
