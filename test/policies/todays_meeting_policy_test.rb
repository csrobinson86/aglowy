require "test_helper"

class TodaysMeetingPolicyTest < ActiveSupport::TestCase
  test "show? and create? yes for a head, an adult and a child of the household" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      policy = TodaysMeetingPolicy.new(memberships(membership), households(:home))

      assert policy.show?, "expected #{membership} to open Today's meeting"
      assert policy.create?, "expected #{membership} to start their notes"
    end
  end

  test "show? and create? no for a nil membership, an inactive one, or a member of another household" do
    [ nil, memberships(:former_in_home), memberships(:outsider_in_other) ].each do |membership|
      policy = TodaysMeetingPolicy.new(membership, households(:home))

      assert_not policy.show?, "expected #{membership&.id.inspect} not to open Today's meeting"
      assert_not policy.create?, "expected #{membership&.id.inspect} not to start notes"
    end
  end
end
