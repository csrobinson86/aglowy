require "test_helper"

class CalendarPolicyTest < ActiveSupport::TestCase
  test "show? yes for a head, an adult and a child of the household" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      assert CalendarPolicy.new(memberships(membership), households(:home)).show?, "expected #{membership} to see the calendar"
    end
  end

  test "show? no for no membership, an inactive one, or a member of another household" do
    [ nil, memberships(:former_in_home), memberships(:outsider_in_other) ].each do |membership|
      assert_not CalendarPolicy.new(membership, households(:home)).show?, "expected #{membership&.id.inspect} not to see the calendar"
    end
  end
end
