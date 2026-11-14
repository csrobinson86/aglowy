require "test_helper"

class HouseholdPolicyTest < ActiveSupport::TestCase
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
