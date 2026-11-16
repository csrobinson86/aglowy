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
end
