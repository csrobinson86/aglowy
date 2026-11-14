require "test_helper"

class HouseholdPolicyTest < ActiveSupport::TestCase
  test "index? and create? are true with a nil membership" do
    policy = HouseholdPolicy.new(nil, Household)

    assert policy.index?
    assert policy.create?
  end

  test "index?, new? and create? are true for every role" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      policy = HouseholdPolicy.new(memberships(membership), Household)

      assert policy.index? && policy.new? && policy.create?, "expected #{membership} to list and create households"
    end
  end

  test "show? yes for head, adult and child" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      assert HouseholdPolicy.new(memberships(membership), households(:home)).show?, "expected #{membership} to see home"
    end
  end

  test "show? no for a nil membership" do
    assert_not HouseholdPolicy.new(nil, households(:home)).show?
  end

  test "show? no for an inactive membership" do
    assert_not HouseholdPolicy.new(memberships(:former_in_home), households(:home)).show?
  end

  test "show? no for a membership in another household" do
    assert_not HouseholdPolicy.new(memberships(:outsider_in_other), households(:home)).show?
  end
end
