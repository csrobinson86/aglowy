require "test_helper"

class IdentitySessionsTest < ActionDispatch::IntegrationTest
  test "a confirmed identity signs in with email and password" do
    sign_in_with identities(:head)

    assert_redirected_to households_path
    assert_equal "Signed in successfully.", flash[:notice]
  end

  test "one active household lands on its page" do
    sign_in_with identities(:spouse)

    assert_redirected_to household_root_path(household_id: households(:home))
  end

  test "several land on the chooser" do
    sign_in_with identities(:head)

    assert_redirected_to households_path
  end

  test "none lands on new household" do
    sign_in_with identities(:staff)

    assert_redirected_to new_household_path
  end

  test "an inactive membership doesn't count" do
    sign_in_with identities(:former)

    assert_redirected_to new_household_path
  end

  test "an unconfirmed identity can't" do
    sign_in_with identities(:newcomer)

    assert_redirected_to new_identity_session_path
    assert_equal "You have to confirm your email address before continuing.", flash[:alert]
  end

  test "a child signs in with a username" do
    sign_in_with identities(:eli)

    assert_redirected_to household_root_path(household_id: households(:home))
  end

  # Paranoid mode: saying "locked" would confirm the account exists.
  test "a locked identity can't, and is told only that the details are invalid" do
    identities(:spouse).lock_access!(send_instructions: false)

    sign_in_with identities(:spouse)

    assert_response :unprocessable_entity
    assert_includes response.body, "Invalid email or username or password."
  end

  private

  def sign_in_with(identity)
    post identity_session_path, params: { identity: { login: identity.login, password: "password123" } }
  end
end
