require "test_helper"

# Mark all as read reads only the person's own visible notifications (docs/design/notifications.md, Pages and routes).
class Notification::ReadingPolicyTest < ActiveSupport::TestCase
  test "a head, an adult and a child may mark all as read" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      assert Notification::ReadingPolicy.new(memberships(membership), Notification::Reading).create?, "expected #{membership} to be allowed"
    end
  end

  test "no membership or an inactive one may not" do
    [ nil, memberships(:former_in_home) ].each do |membership|
      assert_not Notification::ReadingPolicy.new(membership, Notification::Reading).create?, "expected #{membership.inspect} to be refused"
    end
  end
end
