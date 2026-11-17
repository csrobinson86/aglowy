require "test_helper"

# Any active member turns push on and removes their own devices, children too; Current.user.push_subscriptions keeps
# others' out (docs/design/notifications.md, Pages and routes).
class PushSubscriptionPolicyTest < ActiveSupport::TestCase
  test "a head, an adult and a child may turn it on and remove a device" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      policy = PushSubscriptionPolicy.new(memberships(membership), PushSubscription)

      assert policy.create? && policy.destroy?, "expected #{membership} to be allowed"
    end
  end

  test "no membership or an inactive one may not" do
    [ nil, memberships(:former_in_home) ].each do |membership|
      policy = PushSubscriptionPolicy.new(membership, PushSubscription)

      assert_not policy.create? || policy.destroy?, "expected #{membership.inspect} to be refused"
    end
  end
end
