require "test_helper"

class InvitationPolicyTest < ActiveSupport::TestCase
  test "create? yes for a head and an adult" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      assert InvitationPolicy.new(memberships(membership), Invitation).create?, "expected #{membership} to invite"
    end
  end

  test "create? no for a child, an inactive member and a nil membership" do
    [ memberships(:child_in_home), memberships(:former_in_home), nil ].each do |membership|
      assert_not InvitationPolicy.new(membership, Invitation).create?, "expected #{membership&.role.inspect} not to invite"
    end
  end

  test "head and adult can invite as adult" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      assert InvitationPolicy.new(memberships(membership), Invitation).create_as?("adult"), "expected #{membership} to invite an adult"
    end
  end

  test "only a head can invite as head" do
    assert InvitationPolicy.new(memberships(:head_in_home), Invitation).create_as?(:head)
    assert_not InvitationPolicy.new(memberships(:spouse_in_home), Invitation).create_as?(:head)
  end

  test "a child can't invite as anything, and nobody invites as child" do
    %w[ adult head ].each do |role|
      assert_not InvitationPolicy.new(memberships(:child_in_home), Invitation).create_as?(role), "expected a child not to invite as #{role}"
    end
    assert_not InvitationPolicy.new(memberships(:head_in_home), Invitation).create_as?("child")
    assert_not InvitationPolicy.new(nil, Invitation).create_as?("adult")
  end

  test "a head can resend and cancel any invitation in their household" do
    [ invitations(:ana), invitation_from(:spouse) ].each do |invitation|
      policy = InvitationPolicy.new(memberships(:head_in_home), invitation)

      assert policy.update?
      assert policy.destroy?
    end
  end

  test "an adult can cancel their own but not another adult's" do
    own = InvitationPolicy.new(memberships(:spouse_in_home), invitation_from(:spouse))
    others = InvitationPolicy.new(memberships(:spouse_in_home), invitation_from(:former))

    assert own.update?
    assert own.destroy?
    assert_not others.update?
    assert_not others.destroy?
  end

  test "an adult can't resend or cancel a head's invitation" do
    policy = InvitationPolicy.new(memberships(:spouse_in_home), invitations(:ana))

    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "a child, an inactive member and a nil membership can't resend or cancel" do
    [ memberships(:child_in_home), memberships(:former_in_home), nil ].each do |membership|
      policy = InvitationPolicy.new(membership, invitation_from(:former))

      assert_not policy.update?, "expected #{membership&.role.inspect} not to resend"
      assert_not policy.destroy?, "expected #{membership&.role.inspect} not to cancel"
    end
  end

  test "nobody can resend or cancel another household's invitation" do
    invitation = households(:parents).invitations.build(invited_by: users(:head), email: "luz@example.com")
    policy = InvitationPolicy.new(memberships(:head_in_home), invitation)

    assert_not policy.update?
    assert_not policy.destroy?
  end

  private
    def invitation_from(user)
      households(:home).invitations.build(invited_by: users(user), email: "rosa@example.com")
    end
end
