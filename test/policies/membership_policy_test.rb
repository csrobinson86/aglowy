require "test_helper"

class MembershipPolicyTest < ActiveSupport::TestCase
  test "create? yes for a head" do
    assert MembershipPolicy.new(memberships(:head_in_home), Membership).create?
  end

  test "create? no for an adult and a child" do
    %i[ spouse_in_home child_in_home ].each do |membership|
      assert_not MembershipPolicy.new(memberships(membership), Membership).create?, "expected #{membership} not to add members"
    end
  end

  test "create? no for a nil membership" do
    assert_not MembershipPolicy.new(nil, Membership).create?
  end
end
