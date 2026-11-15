require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "requires a user" do
    identity = Identity.new(email: "someone@example.com", password: "password123")

    assert_not identity.valid?
    assert_includes identity.errors[:user], "must exist"
  end

  test "staff defaults to false" do
    assert_equal false, Identity.new.staff
  end

  test "an unconfirmed identity is not active for authentication" do
    assert_not identities(:newcomer).active_for_authentication?
  end

  test "an identity with only a username is valid and needs no confirmation" do
    identity = users(:sofia).build_identity(username: "sofia.rivera", password: "password123")

    assert identity.valid?
    assert_no_emails { identity.save! }
    assert_nil identity.confirmed_at
    assert identity.active_for_authentication?
  end

  test "an identity with an email still needs confirmation" do
    identity = users(:sofia).create_identity!(email: "sofia@example.com", password: "password123")

    assert_not identity.active_for_authentication?
  end

  test "an identity with neither an email nor a username is invalid" do
    identity = users(:sofia).build_identity(password: "password123")

    assert_not identity.valid?
    assert_includes identity.errors[:email], "can't be blank"
  end

  test "usernames are stored lowercase, without surrounding spaces" do
    identity = users(:sofia).create_identity!(username: "  Sofia.Rivera ", password: "password123")

    assert_equal "sofia.rivera", identity.reload.username
  end

  test "a blank email is stored as no email" do
    identity = users(:sofia).create_identity!(username: "sofia.rivera", email: "  ", password: "password123")

    assert_nil identity.reload.email
    assert_equal "sofia.rivera", identity.login
  end

  test "a login with both signs in by either, and needs its email confirmed first" do
    identity = users(:sofia).create_identity!(email: "sofia@example.com", username: "sofia.rivera", password: "password123")

    assert_equal identity, Identity.find_for_database_authentication(login: "sofia@example.com")
    assert_equal identity, Identity.find_for_database_authentication(login: "Sofia.Rivera")
    assert_not identity.active_for_authentication?
  end

  test "a username with @ is invalid" do
    identity = users(:sofia).build_identity(username: "sofia@rivera", password: "password123")

    assert_not identity.valid?
    assert_includes identity.errors[:username], "is invalid"
  end

  test "a username shorter than 3 characters is invalid" do
    identity = users(:sofia).build_identity(username: "so", password: "password123")

    assert_not identity.valid?
    assert_includes identity.errors[:username], "is invalid"
  end

  test "a username already taken, in any case, is invalid" do
    identity = users(:sofia).build_identity(username: "Eli.Rivera", password: "password123")

    assert_not identity.valid?
    assert_includes identity.errors[:username], "has already been taken"
  end

  test "finds a login by email when it contains @, otherwise by username, ignoring case and spaces" do
    assert_equal identities(:head), Identity.find_for_database_authentication(login: " HEAD@example.com ")
    assert_equal identities(:eli), Identity.find_for_database_authentication(login: " ELI.Rivera ")
    assert_nil Identity.find_for_database_authentication(login: "head")
    assert_nil Identity.find_for_database_authentication(login: "")
  end

  test "login is what the person signs in with: the email, or the username without one" do
    assert_equal "head@example.com", identities(:head).login
    assert_equal "eli.rivera", identities(:eli).login
  end

  test "a username-only login unlocks by time and is sent no unlock email" do
    identity = identities(:eli)

    assert_no_emails { identity.lock_access! }
    assert identity.access_locked?
    assert_not identity.unlock_strategy_enabled?(:email)

    travel Identity.unlock_in + 1.minute do
      assert_not identity.access_locked?
    end
  end

  test "an email login unlocks by email or time" do
    identity = identities(:spouse)

    assert_emails(1) { identity.lock_access! }
    assert identity.unlock_strategy_enabled?(:email)
    assert identity.unlock_strategy_enabled?(:time)
  end

  test "a reset link sent to the old email stops working once a new email is confirmed" do
    identity = identities(:spouse)
    token = identity.send_reset_password_instructions

    identity.update!(email: "spouse.new@example.com")
    identity.confirm

    reset = Identity.reset_password_by_token(reset_password_token: token, password: "newpassword123", password_confirmation: "newpassword123")
    assert_includes reset.errors[:reset_password_token], "is invalid"
  end

  test "a reset link stops working once the username changes" do
    identity = identities(:spouse)
    identity.update!(username: "spouse.rivera")
    token = identity.send_reset_password_instructions

    identity.update!(username: "spouse.r")

    reset = Identity.reset_password_by_token(reset_password_token: token, password: "newpassword123", password_confirmation: "newpassword123")
    assert_includes reset.errors[:reset_password_token], "is invalid"
  end

  test "a password-setup token works once: it finds nothing after the password is set" do
    identity = identities(:eli)
    token = identity.generate_token_for(:password_setup)

    assert_equal identity, Identity.find_by_token_for(:password_setup, token)

    identity.update!(password: "chosen-by-eli")

    assert_nil Identity.find_by_token_for(:password_setup, token)
  end

  test "a password-setup token finds nothing after 12 hours" do
    identity = identities(:eli)
    token = identity.generate_token_for(:password_setup)

    travel 12.hours - 1.minute do
      assert_equal identity, Identity.find_by_token_for(:password_setup, token)
    end

    travel 12.hours + 1.second do
      assert_nil Identity.find_by_token_for(:password_setup, token)
    end
  end

  test "database: a duplicate email raises RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      Identity.insert!({ user_id: users(:child).id, email: identities(:head).email, encrypted_password: "x" })
    end
  end

  test "database: a second identity for the same user raises RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      Identity.insert!({ user_id: users(:head).id, email: "second@example.com", encrypted_password: "x" })
    end
  end

  test "database: an identity with neither email nor username raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      Identity.insert!({ user_id: users(:sofia).id, encrypted_password: "x" })
    end
  end

  test "database: a duplicate username raises RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      insert_without_normalizing(username: "eli.rivera")
    end
  end

  # Only lowercase is allowed, so a case variant never reaches the unique index.
  test "database: a username differing only in case from another raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      insert_without_normalizing(username: "Eli.Rivera")
    end
  end

  test "database: a blank email raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      insert_without_normalizing(username: "sofia.rivera", email: "")
    end
  end

  test "database: a username with a space raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      Identity.insert!({ user_id: users(:sofia).id, username: "eli rivera", encrypted_password: "x" })
    end
  end

  private
    # insert! casts through the attribute types, which normalize, so this goes around them.
    def insert_without_normalizing(username:, email: nil)
      Identity.connection.exec_insert(<<~SQL, "SQL", [ users(:sofia).id, email, username ])
        INSERT INTO identities (user_id, email, username, encrypted_password, created_at, updated_at)
        VALUES ($1, $2, $3, 'x', now(), now())
      SQL
    end
end
