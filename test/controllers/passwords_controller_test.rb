require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "forgot password with a username sends no email and shows the same message as an unknown email" do
    assert_no_emails do
      post identity_password_path, params: { identity: { email: "eli.rivera" } }
    end
    assert_redirected_to new_identity_session_path
    username_notice = flash[:notice]

    assert_no_emails do
      post identity_password_path, params: { identity: { email: "nobody@example.com" } }
    end
    assert_redirected_to new_identity_session_path

    assert_equal "If your email address exists in our database, you will receive a password recovery link at your email address in a few minutes.", username_notice
    assert_equal username_notice, flash[:notice]
  end

  test "forgot password with a known email sends reset instructions and shows the same message" do
    assert_emails(1) do
      post identity_password_path, params: { identity: { email: identities(:spouse).email } }
    end

    assert_redirected_to new_identity_session_path
    assert_equal "If your email address exists in our database, you will receive a password recovery link at your email address in a few minutes.", flash[:notice]
  end
end
