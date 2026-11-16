require "test_helper"

class TagPolicyTest < ActiveSupport::TestCase
  test "any active member can list their own tags, whatever their role" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      assert TagPolicy.new(memberships(membership), Tag).index?, "expected #{membership} to be let in"
    end
  end

  test "an inactive or nil membership can't list tags" do
    [ memberships(:former_in_home), nil ].each do |membership|
      assert_not TagPolicy.new(membership, Tag).index?
    end
  end

  test "the owner can show, rename and delete their tag from any household they're in" do
    [ memberships(:head_in_home), memberships(:head_in_parents) ].each do |membership|
      policy = TagPolicy.new(membership, tags(:head_ministry))

      assert policy.show? && policy.update? && policy.destroy?, "expected #{membership.household.name} to let the owner in"
    end
  end

  test "nobody else can, whatever their role, and nor can a nil membership" do
    [ memberships(:spouse_in_home), memberships(:child_in_home), memberships(:former_in_home), nil ].each do |membership|
      policy = TagPolicy.new(membership, tags(:head_ministry))

      assert_not policy.show? || policy.update? || policy.destroy?
    end
  end
end
