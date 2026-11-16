require "test_helper"

class Membership::StudyAiGrantTest < ActiveSupport::TestCase
  test "only for a child membership with an identity" do
    assert memberships(:eli_in_home).grant_study_ai(by: users(:head)).persisted?

    { sofia_in_home: "needs a login first", spouse_in_home: "is only for children" }.each do |name, message|
      grant = memberships(name).grant_study_ai(by: users(:head))

      assert_not grant.persisted?, "expected no grant for #{name}"
      assert_includes grant.errors[:membership], message
    end
  end

  test "not for a child who has left the household" do
    memberships(:eli_in_home).update!(active: false)

    assert_not memberships(:eli_in_home).grant_study_ai(by: users(:head)).persisted?
  end

  test "granting twice finds the first grant" do
    first = memberships(:eli_in_home).grant_study_ai(by: users(:head))

    assert_equal first, memberships(:eli_in_home).grant_study_ai(by: users(:spouse))
    assert_equal users(:head), first.reload.granted_by
  end

  test "revoke_study_ai deletes it" do
    memberships(:eli_in_home).grant_study_ai(by: users(:head))

    memberships(:eli_in_home).revoke_study_ai

    assert_not memberships(:eli_in_home).reload.study_ai_grant?
  end

  test "removing the child from the household ends the grant, so rejoining doesn't bring it back" do
    memberships(:eli_in_home).grant_study_ai(by: users(:head))

    assert memberships(:eli_in_home).deactivate
    assert_not memberships(:eli_in_home).reload.study_ai_grant?
  end

  test "a child made an adult loses the grant" do
    memberships(:eli_in_home).grant_study_ai(by: users(:head))

    assert memberships(:eli_in_home).change_role("adult")
    assert_not memberships(:eli_in_home).reload.study_ai_grant?
  end

  test "destroyed with the membership" do
    memberships(:eli_in_home).grant_study_ai(by: users(:head))

    assert_difference -> { Membership::StudyAiGrant.count }, -1 do
      Membership.where(id: memberships(:eli_in_home)).delete_all
    end
  end

  test "database: the unique index on membership_id refuses a second grant for the same membership" do
    memberships(:eli_in_home).grant_study_ai(by: users(:head))

    assert_raises ActiveRecord::RecordNotUnique do
      Membership::StudyAiGrant.insert!({ membership_id: memberships(:eli_in_home).id, granted_by_id: users(:spouse).id })
    end
  end

  test "database: a grant without granted_by raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      Membership::StudyAiGrant.insert!({ membership_id: memberships(:eli_in_home).id, granted_by_id: nil })
    end
  end
end
