require "test_helper"

class MembershipPolicyTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "index? yes for head, adult and child" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      assert MembershipPolicy.new(memberships(membership), Membership).index?, "expected #{membership} to list members"
    end
  end

  test "index? no for a nil membership" do
    assert_not MembershipPolicy.new(nil, Membership).index?
  end

  test "index? no for an inactive membership" do
    assert_not MembershipPolicy.new(memberships(:former_in_home), Membership).index?
  end

  test "create? yes for a head and an adult" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      assert MembershipPolicy.new(memberships(membership), Membership).create?, "expected #{membership} to add members"
    end
  end

  test "create? no for a child and an inactive member" do
    %i[ child_in_home former_in_home ].each do |membership|
      assert_not MembershipPolicy.new(memberships(membership), Membership).create?, "expected #{membership} not to add members"
    end
  end

  test "create? no for a nil membership" do
    assert_not MembershipPolicy.new(nil, Membership).create?
  end

  test "give_login? yes for a head and an adult, on a child with no login" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      assert MembershipPolicy.new(memberships(membership), memberships(:sofia_in_home)).give_login?, "expected #{membership} to give Sofia a login"
    end
  end

  test "give_login? no for a child, an inactive member or a nil membership" do
    [ memberships(:eli_in_home), memberships(:former_in_home), nil ].each do |membership|
      assert_not MembershipPolicy.new(membership, memberships(:sofia_in_home)).give_login?, "expected #{membership&.user&.name.inspect} not to give a login"
    end
  end

  test "give_login? no on a child who already has a login" do
    assert_not MembershipPolicy.new(memberships(:head_in_home), memberships(:eli_in_home)).give_login?
  end

  test "give_login? no on an adult or a head" do
    rosa = households(:home).add_member(name: "Rosa Rivera", role: "adult")
    users(:head).identity.destroy!

    assert_not MembershipPolicy.new(memberships(:spouse_in_home), rosa).give_login?
    assert_not MembershipPolicy.new(memberships(:spouse_in_home), memberships(:head_in_home)).give_login?
  end

  test "give_login? no on a child in another household" do
    child = households(:other).add_member(name: "Otto Outsider", role: "child")

    assert_not MembershipPolicy.new(memberships(:head_in_home), child).give_login?
  end

  test "new_password_link? yes for a head and an adult, on a child with a username-only login" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      assert MembershipPolicy.new(memberships(membership), memberships(:eli_in_home)).new_password_link?, "expected #{membership} to make Eli a link"
    end
  end

  test "new_password_link? no for a child, an inactive member or a nil membership" do
    [ memberships(:eli_in_home), memberships(:former_in_home), nil ].each do |membership|
      assert_not MembershipPolicy.new(membership, memberships(:eli_in_home)).new_password_link?, "expected #{membership&.user&.name.inspect} not to make a link"
    end
  end

  test "new_password_link? no on a child with no login, or a login with an email" do
    assert_not MembershipPolicy.new(memberships(:head_in_home), memberships(:sofia_in_home)).new_password_link?

    identities(:eli).update_column(:email, "eli@example.com") # update! would hold it as unconfirmed_email
    assert_not MembershipPolicy.new(memberships(:head_in_home), memberships(:eli_in_home).reload).new_password_link?
  end

  test "new_password_link? no on an adult with a username-only login" do
    identities(:spouse).update!(username: "sam.spouse", email: nil)

    assert_not MembershipPolicy.new(memberships(:head_in_home), memberships(:spouse_in_home).reload).new_password_link?
  end

  # A child seat here is no way into an adult or head seat elsewhere (#453).
  test "new_password_link? and give_login? no when the child has an adult or head seat in another household" do
    Membership.create!(user: users(:eli), household: households(:parents), role: :adult)
    Membership.create!(user: users(:sofia), household: households(:parents), role: :head)

    %i[ head_in_home spouse_in_home ].each do |membership|
      assert_not MembershipPolicy.new(memberships(membership), memberships(:eli_in_home)).new_password_link?, "expected #{membership} not to make Eli a link"
      assert_not MembershipPolicy.new(memberships(membership), memberships(:sofia_in_home)).give_login?, "expected #{membership} not to give Sofia a login"
    end
  end

  test "new_password_link? and give_login? still yes when the other seat is a child's or inactive" do
    Membership.create!(user: users(:eli), household: households(:parents), role: :child)
    Membership.create!(user: users(:sofia), household: households(:parents), role: :head, active: false)

    %i[ head_in_home spouse_in_home ].each do |membership|
      assert MembershipPolicy.new(memberships(membership), memberships(:eli_in_home)).new_password_link?, "expected #{membership} to make Eli a link"
      assert MembershipPolicy.new(memberships(membership), memberships(:sofia_in_home)).give_login?, "expected #{membership} to give Sofia a login"
    end
  end

  # Household settings' Members and roles (docs/design/invitations.md, Who can do what).
  test "update? and destroy? yes for a head, on any member of their household, themselves too" do
    %i[ spouse_in_home eli_in_home head_in_home ].each do |member|
      policy = MembershipPolicy.new(memberships(:head_in_home), memberships(member))

      assert policy.update?, "expected the head to change #{member}'s role"
      assert policy.destroy?, "expected the head to remove #{member}"
    end
  end

  test "update? and destroy? no for an adult, a child, an inactive member or a nil membership" do
    [ memberships(:spouse_in_home), memberships(:eli_in_home), memberships(:former_in_home), nil ].each do |membership|
      policy = MembershipPolicy.new(membership, memberships(:child_in_home))

      assert_not policy.update?, "expected #{membership&.user&.name.inspect} not to change roles"
      assert_not policy.destroy?, "expected #{membership&.user&.name.inspect} not to remove members"
    end
  end

  test "update? and destroy? no on a member of another household" do
    policy = MembershipPolicy.new(memberships(:head_in_home), memberships(:outsider_in_other))

    assert_not policy.update?
    assert_not policy.destroy?
  end

  # Leaving is in account settings, outside any household, so the membership is nil there (docs/design/invitations.md).
  test "leave? yes for a head or an adult leaving their own seat" do
    { head: :head_in_home, spouse: :spouse_in_home }.each do |identity, membership|
      Current.identity = identities(identity)

      assert MembershipPolicy.new(nil, memberships(membership)).leave?, "expected #{identity} to leave"
    end
  end

  test "leave? no for a child" do
    Current.identity = identities(:eli)

    assert_not MembershipPolicy.new(nil, memberships(:eli_in_home)).leave?
  end

  test "leave? no for someone else's seat, or with nobody signed in" do
    Current.identity = identities(:spouse)
    assert_not MembershipPolicy.new(nil, memberships(:head_in_home)).leave?

    Current.reset
    assert_not MembershipPolicy.new(nil, memberships(:spouse_in_home)).leave?
  end
end
