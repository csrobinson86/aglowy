require "test_helper"

class RootTest < ActionDispatch::IntegrationTest
  test "a visitor at / sees the sign-in form and a Create an account link" do
    get root_path

    assert_response :success
    assert_select "h1", "Sign in to Aglowy"
    assert_select "form[action=?]", identity_session_path do
      assert_select "input[name='identity[email]'][autocomplete='email'][autofocus]"
      assert_select "input[name='identity[password]'][type='password'][autocomplete='current-password']"
      assert_select "input[name='identity[remember_me]'][type='checkbox']"
      assert_select "button[type='submit']", "Sign in"
    end
    assert_select "a[href=?]", new_identity_password_path, "Forgot password?"
    assert_select "a[href=?]", new_signup_path, "Create an account"
    assert_select "a[href=?]", new_identity_confirmation_path, "Didn't get the confirmation email?"
  end

  test "a signed-in person with one household is redirected to it" do
    sign_in identities(:spouse)

    get root_path

    assert_redirected_to household_root_path(household_id: households(:home))
  end

  test "with several, to the chooser" do
    sign_in identities(:head)

    get root_path

    assert_redirected_to households_path
  end

  test "with none, to new household" do
    sign_in identities(:staff)

    get root_path

    assert_redirected_to new_household_path
  end

  test "a wrong password shows Devise's generic alert and doesn't echo the password back" do
    post identity_session_path, params: { identity: { email: identities(:head).email, password: "wrong-password" } }

    assert_response :unprocessable_content
    assert_select ".flash", /Invalid email or password\./
    assert_select "input[name='identity[email]'][value=?]", identities(:head).email
    assert_select "input[name='identity[password]']:not([value])"
  end
end
