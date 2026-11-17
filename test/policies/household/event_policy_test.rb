require "test_helper"

# Heads and adults add, edit and delete household events; children don't (docs/design/calendar.md, Who can do what; Trap 4).
class Household::EventPolicyTest < ActiveSupport::TestCase
  test "a head and an adult may create, update and destroy" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      policy = Household::EventPolicy.new(memberships(membership), household_events(:co_visit))

      assert policy.create? && policy.new? && policy.update? && policy.edit? && policy.destroy?, "expected #{membership} to manage events"
    end
  end

  test "a child may not" do
    policy = Household::EventPolicy.new(memberships(:child_in_home), household_events(:co_visit))

    assert_not policy.create? || policy.update? || policy.destroy?
  end

  test "no membership or an inactive one may not" do
    [ nil, memberships(:former_in_home) ].each do |membership|
      policy = Household::EventPolicy.new(membership, household_events(:co_visit))

      assert_not policy.create? || policy.update? || policy.destroy?, "expected #{membership.inspect} to be refused"
    end
  end
end
