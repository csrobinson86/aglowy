require "test_helper"

# Changing your own avatar (docs/design/avatars.md, Who can do what): every active member, children included, and only
# their own. A child's, from Settings → Children: heads and adults of a household the child is in, and only a child's.
class AvatarPolicyTest < ActiveSupport::TestCase
  test "update? and destroy? for a head and an adult, on a child of their household" do
    %i[ head_in_home spouse_in_home ].each do |membership|
      %i[ eli sofia ].each do |child|
        policy = AvatarPolicy.new(memberships(membership), users(child))

        assert policy.update?, "expected #{membership} to change #{child}'s avatar"
        assert policy.destroy?, "expected #{membership} to remove #{child}'s photo"
      end
    end
  end

  test "update? and destroy? never for a child, on another child or themselves" do
    [ AvatarPolicy.new(memberships(:eli_in_home), users(:sofia)), AvatarPolicy.new(memberships(:eli_in_home), users(:eli)) ].each do |policy|
      assert_not policy.update?
      assert_not policy.destroy?
    end
  end

  # Traps 5: only children, even for a head.
  test "update? and destroy? never on an adult's or a head's, by anyone" do
    %i[ head_in_home spouse_in_home eli_in_home ].each do |membership|
      %i[ head spouse ].each do |adult|
        policy = AvatarPolicy.new(memberships(membership), users(adult))

        assert_not policy.update?, "expected #{membership} not to change #{adult}'s avatar"
        assert_not policy.destroy?, "expected #{membership} not to remove #{adult}'s photo"
      end
    end
  end

  test "update? never on a child of another household, or a child who's left this one" do
    assert_not AvatarPolicy.new(memberships(:head_in_parents), users(:eli)).update?
    memberships(:eli_in_home).update!(active: false)
    assert_not AvatarPolicy.new(memberships(:head_in_home), users(:eli)).update?
  end

  test "update? and destroy? are false for a nil or inactive membership" do
    [ nil, memberships(:former_in_home) ].each do |membership|
      assert_not AvatarPolicy.new(membership, users(:eli)).update?
      assert_not AvatarPolicy.new(membership, users(:eli)).destroy?
    end
  end

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

  # Outside a household there's no membership: show_avatar? reads Current.user.
  test "show_avatar? for the person, a household mate, but not a stranger, whatever the membership" do
    [ nil, memberships(:head_in_home), memberships(:spouse_in_home), memberships(:eli_in_home) ].each do |membership|
      Current.identity = identities(:head)
      assert AvatarPolicy.new(membership, users(:head)).show_avatar?
      assert AvatarPolicy.new(membership, users(:eli)).show_avatar?

      Current.identity = identities(:outsider)
      assert_not AvatarPolicy.new(membership, users(:eli)).show_avatar?
    end
  end

  test "show_avatar? for an adult and a child signed in: themselves and a household mate, not a stranger" do
    %i[ spouse eli ].each do |viewer|
      Current.identity = identities(viewer)

      [ nil, memberships(:"#{viewer}_in_home") ].each do |membership|
        assert AvatarPolicy.new(membership, users(viewer)).show_avatar?, "expected #{viewer} to see their own"
        assert AvatarPolicy.new(membership, users(:head)).show_avatar?, "expected #{viewer} to see a household mate's"
        assert_not AvatarPolicy.new(membership, users(:outsider)).show_avatar?, "expected #{viewer} not to see a stranger's"
      end
    end
  end

  test "show_avatar? is false signed out" do
    assert_not AvatarPolicy.new(nil, users(:eli)).show_avatar?
  end
end
