require "test_helper"

class CollectionPolicyTest < ActiveSupport::TestCase
  test "any active member can make their own collection, whatever their role" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |name|
      membership = memberships(name)

      assert CollectionPolicy.new(membership, Collection).create?, "expected #{name} to make one"
    end
  end

  test "the owner can change and delete their collection from any household they're in" do
    [ memberships(:head_in_home), memberships(:head_in_parents) ].each do |membership|
      policy = CollectionPolicy.new(membership, collections(:head_talks))

      assert policy.update? && policy.destroy?
    end
  end

  test "an inactive or nil membership can't make one" do
    [ memberships(:former_in_home), nil ].each do |membership|
      assert_not CollectionPolicy.new(membership, Collection).create?
    end
  end

  test "nobody else can change or delete it, whatever their role, and nor can an inactive or nil membership" do
    [ memberships(:spouse_in_home), memberships(:child_in_home), memberships(:former_in_home), nil ].each do |membership|
      policy = CollectionPolicy.new(membership, collections(:head_talks))

      assert_not policy.update? || policy.destroy?
    end
  end
end
