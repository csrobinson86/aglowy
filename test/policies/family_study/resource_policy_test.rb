require "test_helper"

class FamilyStudy::ResourcePolicyTest < ActiveSupport::TestCase
  test "show? yes for head, adult and child" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      assert FamilyStudy::ResourcePolicy.new(memberships(membership), family_study_resources(:study_guide)).show?, "expected #{membership} to open files"
    end
  end

  test "create? yes for a head and an adult" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      assert FamilyStudy::ResourcePolicy.new(memberships(membership), FamilyStudy::Resource).create?, "expected #{membership} to upload files"
    end
  end

  test "create? no for a child" do
    assert_not FamilyStudy::ResourcePolicy.new(memberships(:child_in_home), FamilyStudy::Resource).create?
  end

  test "every action refused for a nil and an inactive membership" do
    [ nil, memberships(:former_in_home) ].each do |membership|
      policy = FamilyStudy::ResourcePolicy.new(membership, family_study_resources(:study_guide))

      assert_not policy.show? || policy.create?, "expected #{membership.inspect} to be refused"
    end
  end
end
