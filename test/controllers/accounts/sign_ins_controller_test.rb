require "test_helper"

class Accounts::SignInsControllerTest < ActionDispatch::IntegrationTest
  setup { ActionMailer::Base.deliveries.clear }

  test "a signed-out visitor is sent to sign in" do
    get edit_account_sign_in_path
    assert_redirected_to new_identity_session_path

    patch account_sign_in_path, params: { identity: { password: "new-password-1" } }
    assert_redirected_to new_identity_session_path
  end

  test "GET /account/sign_in shows the account settings page" do
    sign_in identities(:head)

    get edit_account_sign_in_path

    assert_response :success
    assert_select "main h1", "Account settings"
    assert_select "label[for=identity_current_password]", /Current password/
  end

  test "changing email needs the current password" do
    sign_in identities(:head)

    patch account_sign_in_path, params: { identity: { email: "hannah@example.com", current_password: "" } }

    assert_response :unprocessable_content
    assert_select "#identity_current_password[aria-invalid=true]"
    assert_equal "head@example.com", identities(:head).reload.email
    assert_nil identities(:head).unconfirmed_email
    assert_empty ActionMailer::Base.deliveries
  end

  test "changing email leaves the old email in place until confirmed and mails a confirmation link to the new address" do
    sign_in identities(:head)

    patch account_sign_in_path, params: { identity: { email: "Hannah@Example.com", current_password: "password123" } }

    assert_redirected_to edit_account_path
    assert_equal "Your sign-in details are saved.", flash[:notice]
    identity = identities(:head).reload
    assert_equal "head@example.com", identity.email
    assert_equal "hannah@example.com", identity.unconfirmed_email
    assert_equal [ "hannah@example.com" ], ActionMailer::Base.deliveries.sole.to

    follow_redirect!
    assert_select ".Banner", text: /We sent a link to hannah@example.com\. Your email changes once you open it\. Until then, keep signing in with head@example.com\./
  end

  test "a wrong current password is an error on Current password" do
    sign_in identities(:head)

    patch account_sign_in_path, params: { identity: { password: "new-password-1", current_password: "wrong" } }

    assert_response :unprocessable_content
    assert_select "#identity_current_password[aria-invalid=true]"
    assert_select "#identity_current_password[value]", count: 0
    assert_select "#identity_password[value]", count: 0
    assert identities(:head).reload.valid_password?("password123")
  end

  test "changing password works and keeps you signed in" do
    sign_in identities(:head)

    patch account_sign_in_path, params: { identity: { password: "new-password-1", current_password: "password123" } }

    assert_redirected_to edit_account_path
    assert identities(:head).reload.valid_password?("new-password-1")

    follow_redirect!
    assert_response :success
    assert_select "main h1", "Account settings"
  end

  test "a username-only child can change their password and can't set an email here" do
    sign_in identities(:eli)

    get edit_account_path
    assert_select "#identity_email", count: 0
    assert_select "main dd", "eli.rivera"
    assert_select "main", text: /Needed to change your password\./

    patch account_sign_in_path, params: { identity: { email: "eli@example.com", password: "eli-new-pass", current_password: "password123" } }

    assert_redirected_to edit_account_path
    identity = identities(:eli).reload
    assert identity.valid_password?("eli-new-pass")
    assert_nil identity.email
    assert_nil identity.unconfirmed_email
    assert_empty ActionMailer::Base.deliveries
  end

  test "a failed save keeps return_to" do
    sign_in identities(:head)
    household = households(:home)

    patch account_sign_in_path(return_to: household.id), params: { identity: { password: "new-password-1", current_password: "wrong" } }
    assert_select "main a[href='#{household_root_path(household_id: household)}']", "Back to The Head Family"

    patch account_sign_in_path(return_to: household.id), params: { identity: { password: "new-password-1", current_password: "password123" } }
    assert_redirected_to edit_account_path(return_to: household.id)
  end
end
