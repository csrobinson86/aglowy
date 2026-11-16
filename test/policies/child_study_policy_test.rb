require "test_helper"

class ChildStudyPolicyTest < ActiveSupport::TestCase
  setup { memberships(:eli_in_home).grant_study_ai(by: users(:head)) }

  test "a head here with a grant: yes" do
    policy = ChildStudyPolicy.new(memberships(:head_in_home), memberships(:eli_in_home))

    assert policy.index?
    assert policy.show?
  end

  test "a head here without a grant: no" do
    memberships(:eli_in_home).revoke_study_ai

    assert_not ChildStudyPolicy.new(memberships(:head_in_home), memberships(:eli_in_home)).show?
  end

  test "an adult: no" do
    assert_not ChildStudyPolicy.new(memberships(:spouse_in_home), memberships(:eli_in_home)).show?
  end

  test "a head of another household where the child has no grant: no" do
    eli_in_parents = Membership.create!(household: households(:parents), user: users(:eli), role: :child)

    assert_not ChildStudyPolicy.new(memberships(:grandparent_in_parents), eli_in_parents).show?
    assert_not ChildStudyPolicy.new(memberships(:grandparent_in_parents), memberships(:eli_in_home)).show?
  end

  test "the child, a nil or inactive membership, or a child who has left: no" do
    assert_not ChildStudyPolicy.new(memberships(:eli_in_home), memberships(:eli_in_home)).show?
    assert_not ChildStudyPolicy.new(nil, memberships(:eli_in_home)).show?
    memberships(:eli_in_home).update_column(:active, false)
    assert_not ChildStudyPolicy.new(memberships(:head_in_home), memberships(:eli_in_home)).show?
  end
end
