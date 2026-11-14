require "test_helper"

class FamilyStudy::SessionPolicyTest < ActiveSupport::TestCase
  ROLES = %i[ head_in_home spouse_in_home child_in_home ].freeze

  test "index? and show? yes for head, adult and child" do
    ROLES.each do |membership|
      policy = FamilyStudy::SessionPolicy.new(memberships(membership), family_study_sessions(:weekly_next))

      assert policy.index? && policy.show?, "expected #{membership} to see sessions"
    end
  end

  test "create? and update? yes for a head and an adult" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      policy = FamilyStudy::SessionPolicy.new(memberships(membership), family_study_sessions(:weekly_next))

      assert policy.create? && policy.new? && policy.update? && policy.edit?, "expected #{membership} to edit sessions"
    end
  end

  test "create? and update? no for a child" do
    policy = FamilyStudy::SessionPolicy.new(memberships(:child_in_home), family_study_sessions(:weekly_next))

    assert_not policy.create?
    assert_not policy.update?
  end

  test "every action refused for a nil and an inactive membership" do
    [ nil, memberships(:former_in_home) ].each do |membership|
      policy = FamilyStudy::SessionPolicy.new(membership, family_study_sessions(:weekly_next))

      assert_not policy.index? || policy.show? || policy.create? || policy.update?, "expected #{membership.inspect} to be refused"
    end
  end
end
