require "test_helper"

class MeetingPrepPolicyTest < ActiveSupport::TestCase
  setup do
    households(:home).enable_meeting_helper(by: users(:head))
    households(:home).enable_meeting_prep(by: users(:head))
  end

  test "a child with both on: her pages" do
    policy = MeetingPrepPolicy.new(memberships(:eli_in_home), households(:home))

    assert policy.index?
    assert policy.show?
  end

  test "the helper off: no" do
    households(:home).disable_meeting_helper

    assert_not MeetingPrepPolicy.new(memberships(:eli_in_home), households(:home)).show?
  end

  test "Get ready off: no" do
    households(:home).disable_meeting_prep

    assert_not MeetingPrepPolicy.new(memberships(:eli_in_home), households(:home)).show?
  end

  test "a head: no, Get ready too until the parent's page" do
    policy = MeetingPrepPolicy.new(memberships(:head_in_home), households(:home))

    assert_not policy.index?
    assert_not policy.show?
  end

  test "an adult: no, Get ready too until the parent's page" do
    policy = MeetingPrepPolicy.new(memberships(:spouse_in_home), households(:home))

    assert_not policy.index?
    assert_not policy.show?
  end

  test "a non-member: no" do
    households(:other).enable_meeting_helper(by: users(:outsider))
    households(:other).enable_meeting_prep(by: users(:outsider))
    memberships(:eli_in_home).update!(active: false)

    assert_not MeetingPrepPolicy.new(nil, households(:home)).show?
    assert_not MeetingPrepPolicy.new(memberships(:eli_in_home), households(:home)).show?
    assert_not MeetingPrepPolicy.new(memberships(:child_in_home), households(:other)).show?
  end
end
