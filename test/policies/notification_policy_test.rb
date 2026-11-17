require "test_helper"

# Any active member opens the inbox and their own notifications; Current.user.notifications.visible keeps others out
# (docs/design/notifications.md, Pages and routes).
class NotificationPolicyTest < ActiveSupport::TestCase
  test "a head, an adult and a child may list and open" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      policy = NotificationPolicy.new(memberships(membership), Notification)

      assert policy.index? && policy.show?, "expected #{membership} to be allowed"
    end
  end

  test "no membership or an inactive one may not" do
    [ nil, memberships(:former_in_home) ].each do |membership|
      policy = NotificationPolicy.new(membership, Notification)

      assert_not policy.index? || policy.show?, "expected #{membership.inspect} to be refused"
    end
  end
end
