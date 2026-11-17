require "test_helper"

# Settings → Signing in (docs/design/settings.md; docs/design/invitations.md, Account settings).
class Settings::SignInsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @home = households(:home)
    ActionMailer::Base.deliveries.clear
  end

  test "a head, an adult and a child see Signing in" do
    %i[ head spouse eli ].each do |identity|
      sign_in identities(identity)

      get household_settings_sign_in_path(household_id: @home)

      assert_response :success
      assert_select "main h2", "Signing in"
      assert_select "main", text: /How you sign in to Aglowy\./
      assert_select "nav[aria-label='Settings'] a[aria-current=page]", "Signing in"
      assert_select "form[action=?] #identity_password", household_settings_sign_in_path(household_id: @home)
    end
  end

  test "a head and an adult change their password, stay signed in and come back to Signing in" do
    %i[ head spouse ].each do |identity|
      sign_in identities(identity)

      patch household_settings_sign_in_path(household_id: @home), params: { identity: { password: "new-password-1", current_password: "password123" } }

      assert_redirected_to household_settings_sign_in_path(household_id: @home)
      assert_equal "Your sign-in details are saved.", flash[:notice]
      assert identities(identity).reload.valid_password?("new-password-1")

      follow_redirect!
      assert_response :success
    end
  end

  test "an email change waits for confirmation and shows the Banner" do
    sign_in identities(:head)

    patch household_settings_sign_in_path(household_id: @home), params: { identity: { email: "hannah@example.com", current_password: "password123" } }

    assert_redirected_to household_settings_sign_in_path(household_id: @home)
    assert_equal [ "head@example.com", "hannah@example.com" ], [ identities(:head).reload.email, identities(:head).unconfirmed_email ]
    follow_redirect!
    assert_select ".Banner", text: /We sent a link to hannah@example.com\./
  end

  test "a child can change their password but not their email" do
    sign_in identities(:eli)

    get household_settings_sign_in_path(household_id: @home)
    assert_select "#identity_email", count: 0
    assert_select "main dd", "eli.rivera"

    patch household_settings_sign_in_path(household_id: @home), params: { identity: { email: "eli@example.com", password: "eli-new-pass", current_password: "password123" } }

    assert_redirected_to household_settings_sign_in_path(household_id: @home)
    identity = identities(:eli).reload
    assert identity.valid_password?("eli-new-pass")
    assert_nil identity.email
    assert_nil identity.unconfirmed_email
    assert_empty ActionMailer::Base.deliveries
  end

  test "a refused save re-renders Signing in with 422, for a head, an adult and a child" do
    %i[ head spouse eli ].each do |identity|
      sign_in identities(identity)

      patch household_settings_sign_in_path(household_id: @home), params: { identity: { password: "new-password-1", current_password: "wrong" } }

      assert_response :unprocessable_content
      assert_select "main h2", "Signing in"
      assert_select "#identity_current_password[aria-invalid=true]"
      assert_select "#identity_password[value]", count: 0
      assert identities(identity).reload.valid_password?("password123")
    end
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)
    get household_settings_sign_in_path(household_id: @home)
    assert_response :not_found

    sign_in identities(:outsider)
    patch household_settings_sign_in_path(household_id: @home), params: { identity: { password: "new-password-1", current_password: "password123" } }
    assert_response :not_found
    assert identities(:outsider).reload.valid_password?("password123")
  end
end
