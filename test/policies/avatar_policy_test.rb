require "test_helper"

# Changing your own avatar (docs/design/avatars.md, Who can do what): every active member, children included, and only
# their own.
class AvatarPolicyTest < ActiveSupport::TestCase
  test "update_own? for a head, an adult and a child, on themselves" do
    %i[ head_in_home spouse_in_home eli_in_home ].each do |membership|
      seat = memberships(membership)

      assert AvatarPolicy.new(seat, seat.user).update_own?, "expected #{membership} to change their own avatar"
    end
  end

  test "update_own? never on someone else, even a head on their child" do
    assert_not AvatarPolicy.new(memberships(:head_in_home), users(:eli)).update_own?
    assert_not AvatarPolicy.new(memberships(:eli_in_home), users(:head)).update_own?
  end

  test "update_own? is false for a nil or inactive membership" do
    assert_not AvatarPolicy.new(nil, users(:eli)).update_own?
    assert_not AvatarPolicy.new(memberships(:former_in_home), users(:former)).update_own?
  end
end
