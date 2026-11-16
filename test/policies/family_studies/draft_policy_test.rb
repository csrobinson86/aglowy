require "test_helper"

class FamilyStudies::DraftPolicyTest < ActiveSupport::TestCase
  test "create? yes for a head and an adult" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      assert FamilyStudies::DraftPolicy.new(memberships(membership), FamilyStudy::Draft).create?, "expected #{membership} to draft"
    end
  end

  test "create? no for a child" do
    assert_not FamilyStudies::DraftPolicy.new(memberships(:child_in_home), FamilyStudy::Draft).create?
  end

  test "create? no for a nil and an inactive membership" do
    [ nil, memberships(:former_in_home) ].each do |membership|
      assert_not FamilyStudies::DraftPolicy.new(membership, FamilyStudy::Draft).create?, "expected #{membership.inspect} to be refused"
    end
  end

  test "show? and destroy? yes for a head and an adult on their own draft" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      policy = FamilyStudies::DraftPolicy.new(memberships(membership), family_study_draft(user: memberships(membership).user))

      assert policy.show?, "expected #{membership} to see their draft"
      assert policy.destroy?, "expected #{membership} to stop or discard their draft"
    end
  end

  test "show? and destroy? no on someone else's draft" do
    policy = FamilyStudies::DraftPolicy.new(memberships(:spouse_in_home), family_study_draft(user: users(:head)))

    assert_not policy.show?
    assert_not policy.destroy?
  end

  test "show? and destroy? no for a child, even on their own draft, and for a nil membership" do
    [ memberships(:child_in_home), nil ].each do |membership|
      policy = FamilyStudies::DraftPolicy.new(membership, family_study_draft(user: memberships(:child_in_home).user))

      assert_not policy.show?, "expected #{membership.inspect} to be refused"
      assert_not policy.destroy?, "expected #{membership.inspect} to be refused"
    end
  end
end
