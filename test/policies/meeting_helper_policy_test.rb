require "test_helper"

class MeetingHelperPolicyTest < ActiveSupport::TestCase
  setup { households(:home).enable_meeting_helper(by: users(:head)) }

  test "a child with the helper on: yes" do
    assert MeetingHelperPolicy.new(memberships(:eli_in_home), households(:home)).show?
  end

  test "a child with it off: no" do
    households(:home).disable_meeting_helper

    assert_not MeetingHelperPolicy.new(memberships(:eli_in_home), households(:home)).show?
  end

  test "a head or adult with it on: no" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      assert_not MeetingHelperPolicy.new(memberships(membership), households(:home)).show?, "expected #{membership} not to get the helper"
    end
  end

  test "another household: no" do
    households(:other).enable_meeting_helper(by: users(:outsider))

    assert_not MeetingHelperPolicy.new(memberships(:eli_in_home), households(:other)).show?
  end

  test "a nil or inactive membership: no" do
    memberships(:eli_in_home).update!(active: false)

    assert_not MeetingHelperPolicy.new(nil, households(:home)).show?
    assert_not MeetingHelperPolicy.new(memberships(:eli_in_home), households(:home)).show?
  end
end
