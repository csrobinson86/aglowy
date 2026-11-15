require "test_helper"

class Goal::StepPolicyTest < ActiveSupport::TestCase
  test "head and adult add, edit and remove steps on an open family goal" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      policy = Goal::StepPolicy.new(memberships(membership), goal_steps(:parables))

      assert policy.create? && policy.update? && policy.destroy?, "expected #{membership} to change steps"
    end
  end

  test "a child can't" do
    policy = Goal::StepPolicy.new(memberships(:child_in_home), goal_steps(:parables))

    assert_not policy.create? || policy.update? || policy.destroy?
  end

  test "a member of another household, an inactive member or a nil membership can't" do
    [ memberships(:outsider_in_other), memberships(:head_in_parents), memberships(:former_in_home), nil ].each do |membership|
      policy = Goal::StepPolicy.new(membership, goal_steps(:parables))

      assert_not policy.create? || policy.update? || policy.destroy?, "expected #{membership.inspect} to be refused"
    end
  end

  test "nobody changes the steps of a completed or archived goal" do
    [ goals(:proverbs), goals(:songs) ].each do |goal|
      policy = Goal::StepPolicy.new(memberships(:head_in_home), goal.steps.new)

      assert_not policy.create? || policy.update? || policy.destroy?, "expected #{goal.title} to take no step changes"
    end
  end

  test "the owner changes a personal goal's steps" do
    policy = Goal::StepPolicy.new(memberships(:spouse_in_home), goals(:spouse_bible_reading).steps.new)

    assert policy.create? && policy.update? && policy.destroy?
    assert_not Goal::StepPolicy.new(memberships(:head_in_home), goals(:spouse_bible_reading).steps.new).create?
  end
end
