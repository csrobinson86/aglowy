require "test_helper"

class PersonalStudyPolicyTest < ActiveSupport::TestCase
  test "any active member can list and start their own studies, whatever their role" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |name|
      membership = memberships(name)

      assert PersonalStudyPolicy.new(membership, PersonalStudy).index?, "expected #{name} to list"
      assert PersonalStudyPolicy.new(membership, membership.user.personal_studies.new).create?, "expected #{name} to start one"
    end
  end

  test "an inactive or nil membership can't list or start studies" do
    [ memberships(:former_in_home), nil ].each do |membership|
      assert_not PersonalStudyPolicy.new(membership, PersonalStudy).index?
      assert_not PersonalStudyPolicy.new(membership, users(:former).personal_studies.new).create?
    end
  end

  test "the owner can show, change, delete, tag and ask in their study from any household they're in" do
    [ memberships(:head_in_home), memberships(:head_in_parents) ].each do |membership|
      policy = PersonalStudyPolicy.new(membership, personal_studies(:head_suffering))

      assert policy.show? && policy.update? && policy.destroy? && policy.tag? && policy.ask?, "expected #{membership.household.name} to let the owner in"
    end
  end

  test "nobody else can, whatever their role, and nor can a nil membership" do
    [ memberships(:spouse_in_home), memberships(:child_in_home), memberships(:former_in_home), nil ].each do |membership|
      policy = PersonalStudyPolicy.new(membership, personal_studies(:head_suffering))

      assert_not policy.show? || policy.update? || policy.destroy? || policy.tag? || policy.ask? || policy.create?
    end
  end
end
