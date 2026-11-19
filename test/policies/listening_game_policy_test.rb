require "test_helper"

class ListeningGamePolicyTest < ActiveSupport::TestCase
  setup { households(:home).enable_meeting_helper(by: users(:head)) }

  test "a head with the helper on: yes" do
    assert ListeningGamePolicy.new(memberships(:head_in_home), households(:home)).show?
    assert ListeningGamePolicy.new(memberships(:head_in_home), households(:home)).update?
  end

  test "an adult with the helper on: yes" do
    assert ListeningGamePolicy.new(memberships(:spouse_in_home), households(:home)).show?
    assert ListeningGamePolicy.new(memberships(:spouse_in_home), households(:home)).update?
  end

  test "a child: no" do
    assert_not ListeningGamePolicy.new(memberships(:eli_in_home), households(:home)).show?
    assert_not ListeningGamePolicy.new(memberships(:eli_in_home), households(:home)).update?
  end

  test "the helper off: no" do
    households(:home).disable_meeting_helper

    assert_not ListeningGamePolicy.new(memberships(:head_in_home), households(:home)).show?
    assert_not ListeningGamePolicy.new(memberships(:head_in_home), households(:home)).update?
  end

  test "another household: no" do
    households(:other).enable_meeting_helper(by: users(:outsider))

    assert_not ListeningGamePolicy.new(memberships(:head_in_home), households(:other)).show?
  end

  test "a nil or inactive membership: no" do
    assert_not ListeningGamePolicy.new(nil, households(:home)).show?
    assert_not ListeningGamePolicy.new(memberships(:former_in_home), households(:home)).show?
  end
end
