require "test_helper"

class PasswordSetupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @identity = identities(:eli)
    @token = @identity.generate_token_for(:password_setup)
  end

  # The link is a bearer secret: neither the Rails request log nor Lograge may write it (docs/design/invitations.md, Traps).
  test "GET /password_setup?token=… keeps the token out of the Lograge line and the Rails request log" do
    log = StringIO.new
    lograge_logger, Lograge.logger = Lograge.logger, ActiveSupport::Logger.new(log)

    get edit_password_setup_path(token: @token)

    assert_response :success
    assert_equal "/password_setup?token=[FILTERED]", request.filtered_path

    line = JSON.parse(log.string.lines.grep(/"controller":"PasswordSetupsController"/).sole)
    assert_equal "/password_setup", line["path"]
    assert_equal({ "token" => "[FILTERED]" }, line["params"])
    assert_not_includes log.string, @token
  ensure
    Lograge.logger = lograge_logger
  end

  test "the page greets the child by name and shows the username" do
    get edit_password_setup_path(token: @token)

    assert_response :success
    assert_select "title", "Choose your password"
    assert_select "h1", "Hi Eli! Choose your password"
    assert_select "dd", "eli.rivera"
    assert_select "label", /\APassword/
    assert_select "label", /\AType it again/
  end

  test "sets the password and signs in" do
    patch password_setup_path(token: @token), params: { identity_password_setup: { password: "eli-picks-this", password_confirmation: "eli-picks-this" } }

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_equal "Your password is saved.", flash[:notice]
    assert @identity.reload.valid_password?("eli-picks-this")

    follow_redirect!
    assert_response :success
    assert_select "h1", /Home/
  end

  test "a forgotten password on a locked login: the new password unlocks it" do
    @identity.lock_access!
    token = @identity.reload.generate_token_for(:password_setup)

    patch password_setup_path(token: token), params: { identity_password_setup: { password: "eli-picks-this", password_confirmation: "eli-picks-this" } }

    assert_redirected_to household_root_path(household_id: households(:home))
    assert_not @identity.reload.access_locked?
  end

  test "passwords that don't match show the form again and change nothing" do
    assert_no_changes -> { @identity.reload.encrypted_password } do
      patch password_setup_path(token: @token), params: { identity_password_setup: { password: "eli-picks-this", password_confirmation: "something-else" } }
    end

    assert_response :unprocessable_content
    assert_select "h1", "Hi Eli! Choose your password"
    assert_includes response.body, "doesn&#39;t match"
  end

  test "a password that's too short shows the form again" do
    patch password_setup_path(token: @token), params: { identity_password_setup: { password: "abc", password_confirmation: "abc" } }

    assert_response :unprocessable_content
    assert_includes response.body, "too short"
  end

  test "a used or expired token shows the message and changes nothing" do
    expired = @token
    travel 12.hours + 1.second do
      get edit_password_setup_path(token: expired)
      assert_response :not_found
      assert_includes response.body, "This link has expired or been used. Ask a parent to make a new link."
      assert_not_includes response.body, "eli.rivera"

      assert_no_changes -> { @identity.reload.encrypted_password } do
        patch password_setup_path(token: expired), params: { identity_password_setup: { password: "eli-picks-this", password_confirmation: "eli-picks-this" } }
      end
      assert_response :not_found
    end

    @identity.update!(password: "already-chosen")
    get edit_password_setup_path(token: @token)
    assert_response :not_found
    assert_includes response.body, "This link has expired or been used."

    get edit_password_setup_path(token: "garbage")
    assert_response :not_found

    get edit_password_setup_path
    assert_response :not_found
  end

  test "the response has no-store" do
    get edit_password_setup_path(token: @token)

    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "a password set while this submission waits for the lock shows the message and keeps that password" do
    other = Devise::Encryptor.digest(Identity, "set-meanwhile")
    set_at_lock = ->(*, payload) { Identity.where(id: @identity.id).update_all(encrypted_password: other) if payload[:sql].match?(/FROM "identities".*FOR UPDATE/) }

    ActiveSupport::Notifications.subscribed(set_at_lock, "sql.active_record") do
      patch password_setup_path(token: @token), params: { identity_password_setup: { password: "eli-picks-this", password_confirmation: "eli-picks-this" } }
    end

    assert_response :not_found
    assert_includes response.body, "This link has expired or been used."
    assert @identity.reload.valid_password?("set-meanwhile")
  end

  test "a second submission with the same token after the first has saved is refused and leaves the first password in place" do
    patch password_setup_path(token: @token), params: { identity_password_setup: { password: "first-password", password_confirmation: "first-password" } }
    assert_redirected_to household_root_path(household_id: households(:home))
    sign_out :identity

    patch password_setup_path(token: @token), params: { identity_password_setup: { password: "second-password", password_confirmation: "second-password" } }

    assert_response :not_found
    assert_includes response.body, "This link has expired or been used."
    assert @identity.reload.valid_password?("first-password")
    assert_not @identity.valid_password?("second-password")
  end
end
