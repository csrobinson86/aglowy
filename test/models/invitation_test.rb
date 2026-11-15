require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "email is normalized" do
    invitation = households(:home).invitations.create!(invited_by: users(:head), email: "  Rosa.Rivera@Example.COM ")

    assert_equal "rosa.rivera@example.com", invitation.email
  end

  test "inviting an active member is invalid" do
    invitation = households(:home).invitations.build(invited_by: users(:head), email: "Spouse@example.com")

    assert_not invitation.valid?
    assert_includes invitation.errors[:email], "Already a member of this household."
  end

  test "inviting someone who left the household or belongs to another one is valid" do
    assert households(:home).invitations.build(invited_by: users(:head), email: "former@example.com").valid?
    assert households(:home).invitations.build(invited_by: users(:head), email: "outsider@example.com").valid?
  end

  test "the same address can be invited to two households" do
    invitation = households(:parents).invitations.build(invited_by: users(:grandparent), email: invitations(:ana).email)

    assert invitation.valid?
  end

  test "an invitation needs a valid email and a role of adult or head" do
    invitation = households(:home).invitations.build(invited_by: users(:head), email: "not an email", role: "child")

    assert_not invitation.valid?
    assert_includes invitation.errors[:email], "is invalid"
    assert_includes invitation.errors[:role], "is not included in the list"
  end

  test "a new invitation is for an adult and expires in 7 days" do
    freeze_time do
      invitation = Invitation.new

      assert invitation.adult?
      assert_equal 7.days.from_now, invitation.expires_at
    end
  end

  test "find_by_token_for(:acceptance) finds it" do
    invitation = invitations(:ana)

    assert_equal invitation, Invitation.find_by_token_for(:acceptance, invitation.generate_token_for(:acceptance))
  end

  test "find_by_token_for(:acceptance) finds nothing after resend" do
    invitation = invitations(:ana)
    token = invitation.generate_token_for(:acceptance)

    travel 1.minute
    invitation.resend

    assert_nil Invitation.find_by_token_for(:acceptance, token)
  end

  test "find_by_token_for(:acceptance) finds nothing after 7 days" do
    invitation = invitations(:ana)
    token = invitation.generate_token_for(:acceptance)

    travel 7.days + 1.second

    assert_nil Invitation.find_by_token_for(:acceptance, token)
  end

  test "find_by_token_for(:acceptance) finds nothing after it's deleted" do
    invitation = invitations(:ana)
    token = invitation.generate_token_for(:acceptance)

    invitation.destroy!

    assert_nil Invitation.find_by_token_for(:acceptance, token)
  end

  test "resend moves expires_at to 7 days from now" do
    invitation = invitations(:expired)

    freeze_time do
      invitation.resend

      assert_equal 7.days.from_now, invitation.reload.expires_at
      assert_not invitation.expired?
    end
  end

  test "resend sends the email again" do
    assert_enqueued_email_with InvitationMailer, :invite, params: { invitation: invitations(:ana) } do
      invitations(:ana).resend
    end
  end

  test "resend raises RecordNotFound once a join or cancel has deleted the invitation" do
    stale = Invitation.find(invitations(:ana).id)
    invitations(:ana).destroy!

    assert_no_enqueued_emails do
      assert_raises(ActiveRecord::RecordNotFound) { stale.resend }
    end
  end

  test "deliver_later enqueues the invitation email" do
    assert_enqueued_email_with InvitationMailer, :invite, params: { invitation: invitations(:ana) } do
      invitations(:ana).deliver_later
    end
  end

  test "expired? is true once expires_at has passed" do
    assert invitations(:expired).expired?
    assert_not invitations(:ana).expired?
  end

  test "find_acceptable finds an open invitation" do
    invitation = invitations(:ana)

    assert_equal invitation, Invitation.find_acceptable(invitation.generate_token_for(:acceptance))
  end

  test "find_acceptable returns nil one second after expires_at, even with a token still within its own lifetime" do
    invitation = invitations(:ana)
    travel_to invitation.expires_at - 1.minute
    token = invitation.generate_token_for(:acceptance)

    travel 1.minute + 1.second

    assert_equal invitation, Invitation.find_by_token_for(:acceptance, token)
    assert_nil Invitation.find_acceptable(token)
  end

  test "find_acceptable returns nil for a tampered token" do
    assert_nil Invitation.find_acceptable("not-a-token")
  end

  test "a token in the request parameters is filtered from the logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter("token" => invitations(:ana).generate_token_for(:acceptance))["token"]
  end

  test "deleting the household deletes its invitations" do
    assert_difference -> { Invitation.count }, -2 do
      households(:home).destroy!
    end
  end

  test "deleting the person who sent them deletes their invitations" do
    assert_equal invitations(:ana, :expired).to_set, users(:head).sent_invitations.to_set

    assert_difference -> { Invitation.count }, -2 do
      users(:head).destroy!
    end
  end

  test "database: a second invitation for the same address and household raises RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      Invitation.insert!({ household_id: households(:home).id, invited_by_id: users(:spouse).id, email: invitations(:ana).email, role: "adult", expires_at: 7.days.from_now })
    end
  end

  test "database: role child raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      Invitation.insert!({ household_id: households(:home).id, invited_by_id: users(:head).id, email: "kid@example.com", role: "child", expires_at: 7.days.from_now })
    end
  end
end
