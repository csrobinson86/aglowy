require "test_helper"

class GoalPolicyTest < ActiveSupport::TestCase
  test "every active member can list the household's goals; an inactive member or a nil membership can't" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      assert GoalPolicy.new(memberships(membership), Goal).index?, "expected #{membership} to list goals"
    end

    [ memberships(:former_in_home), nil ].each do |membership|
      assert_not GoalPolicy.new(membership, Goal).index?, "expected #{membership.inspect} to be refused"
    end
  end

  test "family goal: head, adult and child can show" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      assert GoalPolicy.new(memberships(membership), goals(:gospels)).show?, "expected #{membership} to see the goal"
    end
  end

  test "family goal: only head and adult can create, update and destroy" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      policy = GoalPolicy.new(memberships(membership), goals(:gospels))

      assert policy.update? && policy.edit? && policy.destroy?, "expected #{membership} to change the goal"
      assert GoalPolicy.new(memberships(membership), households(:home).goals.new).create?, "expected #{membership} to set a goal"
    end

    policy = GoalPolicy.new(memberships(:child_in_home), goals(:gospels))
    assert_not policy.update? || policy.destroy?
    assert_not GoalPolicy.new(memberships(:child_in_home), households(:home).goals.new).create?
  end

  test "family goal: a member of another household can't show" do
    %i[ outsider_in_other head_in_parents grandparent_in_parents ].each do |membership|
      policy = GoalPolicy.new(memberships(membership), goals(:gospels))

      assert_not policy.show? || policy.update? || policy.destroy?, "expected #{membership} to be refused"
    end
  end

  test "family goal: an inactive member or a nil membership can't" do
    [ memberships(:former_in_home), nil ].each do |membership|
      policy = GoalPolicy.new(membership, goals(:gospels))

      assert_not policy.show? || policy.update? || policy.destroy?, "expected #{membership.inspect} to be refused"
      assert_not GoalPolicy.new(membership, households(:home).goals.new).create?
    end
  end

  test "personal goal: the owner can do everything" do
    policy = GoalPolicy.new(memberships(:spouse_in_home), goals(:spouse_bible_reading))

    assert policy.show? && policy.update? && policy.edit? && policy.destroy?
    assert GoalPolicy.new(memberships(:spouse_in_home), users(:spouse).goals.new).create?
  end

  test "personal goal: another member of the same household can't show, whatever their role" do
    %i[ head_in_home child_in_home ].each do |membership|
      policy = GoalPolicy.new(memberships(membership), goals(:spouse_bible_reading))

      assert_not policy.show? || policy.update? || policy.destroy?, "expected #{membership} to be refused"
      assert_not GoalPolicy.new(memberships(membership), users(:spouse).goals.new).create?
    end
  end

  test "personal goal: a nil membership can't" do
    policy = GoalPolicy.new(nil, goals(:spouse_bible_reading))

    assert_not policy.show? || policy.update? || policy.destroy?
    assert_not GoalPolicy.new(nil, users(:spouse).goals.new).create?
  end

  test "personal goal: the owner through an inactive membership can't" do
    memberships(:spouse_in_home).update_column(:active, false)
    policy = GoalPolicy.new(memberships(:spouse_in_home), goals(:spouse_bible_reading))

    assert_not policy.show? || policy.update? || policy.destroy?
  end
end
