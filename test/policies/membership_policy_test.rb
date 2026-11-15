require "test_helper"

class MembershipPolicyTest < ActiveSupport::TestCase
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
end
