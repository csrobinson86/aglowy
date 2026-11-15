require "test_helper"

class InvitationSignupTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  NEW_ROWS = %w[ User.count Identity.count Membership.count ]

  setup do
    @invitation = invitations(:ana)
    @token = @invitation.generate_token_for(:acceptance)
  end

  test "creates one user, one confirmed identity and one membership with the invited role, and deletes the invitation" do
    @invitation.update!(role: :head)
    signup = InvitationSignup.new(token: @token, name: "Ana Ortiz", password: "password123")

    assert_difference NEW_ROWS, 1 do
      assert_difference "Invitation.count", -1 do
        assert_no_emails { assert signup.save }
      end
    end

    identity = Identity.find_by!(email: "ana.ortiz@example.com")
    assert identity.confirmed?
    assert identity.valid_password?("password123")
    assert_equal "Ana Ortiz", identity.user.name
    assert_equal identity, signup.identity

    membership = identity.user.memberships.sole
    assert_equal households(:home), membership.household
    assert membership.head?
    assert membership.active?
    assert_not Invitation.exists?(@invitation.id)
  end

  # Gotcha 13: an invite sign-up joins the inviting household and starts none of its own.
  test "creates no household" do
    assert_no_difference "Household.count" do
      assert InvitationSignup.new(token: @token, name: "Ana Ortiz", password: "password123").save
    end
  end

  test "ignores an email passed in" do
    signup = InvitationSignup.new(token: @token, name: "Ana Ortiz", password: "password123", email: "someone.else@example.com")

    assert signup.save

    assert_equal "ana.ortiz@example.com", signup.identity.email
    assert_not Identity.exists?(email: "someone.else@example.com")
  end

  test "fails cleanly when the invitation was deleted in the meantime" do
    signup = InvitationSignup.new(token: @token, name: "Ana Ortiz", password: "password123")
    assert signup.invitation

    @invitation.cancel

    assert_no_difference NEW_ROWS do
      assert_not signup.save
    end
    assert_nil signup.invitation
  end

  test "a resend between building and saving is caught under the lock: it fails and creates nothing" do
    signup = InvitationSignup.new(token: @token, name: "Ana Ortiz", password: "password123")
    assert_equal @invitation, signup.invitation

    travel 1.minute do
      assert @invitation.resend
    end

    assert_no_difference NEW_ROWS + %w[ Invitation.count ] do
      assert_not signup.save
    end
    assert_nil signup.invitation
  end

  test "a token past the invitation's deadline finds no invitation" do
    @invitation.update_column(:expires_at, 1.minute.ago)

    assert_nil InvitationSignup.new(token: @token).invitation
    assert_not InvitationSignup.new(token: @token, name: "Ana Ortiz", password: "password123").save
  end

  test "a missing name or a short password creates nothing and keeps the invitation" do
    blank_name = InvitationSignup.new(token: @token, name: " ", password: "password123")
    short_password = InvitationSignup.new(token: @token, name: "Ana Ortiz", password: "short")

    assert_no_difference NEW_ROWS + %w[ Invitation.count ] do
      assert_not blank_name.save
      assert_not short_password.save
    end

    assert_includes blank_name.errors[:name], "can't be blank"
    assert_includes short_password.errors[:password], "is too short (minimum is 6 characters)"
  end

  # Another sign-up took the address after the page was shown (gotcha 3): the unique index stops this one.
  test "losing the race for the email gets the email error, not an exception" do
    signup = InvitationSignup.new(token: @token, name: "Ana Ortiz", password: "password123")
    uniqueness = Identity.validators_on(:email).grep(ActiveRecord::Validations::UniquenessValidator).sole
    uniqueness.define_singleton_method(:validate) { |_record| }
    identities(:newcomer).update_column(:email, "ana.ortiz@example.com")

    assert_no_difference NEW_ROWS + %w[ Invitation.count ] do
      assert_not signup.save
    end

    assert_includes signup.errors[:email], "has already been taken"
  ensure
    uniqueness.singleton_class.remove_method(:validate)
  end

  test "reads the email and household from the invitation" do
    signup = InvitationSignup.new(token: @token)

    assert_equal "ana.ortiz@example.com", signup.email
    assert_equal households(:home), signup.household
  end
end
