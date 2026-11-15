require "test_helper"

# Account settings are outside any household, so the membership is nil there (docs/design/invitations.md, Account settings).
class UserPolicyTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "update? and edit? only for the signed-in person themselves" do
    Current.identity = identities(:spouse)

    assert UserPolicy.new(nil, users(:spouse)).update?
    assert UserPolicy.new(nil, users(:spouse)).edit?
    assert_not UserPolicy.new(nil, users(:head)).update?
    assert_not UserPolicy.new(nil, users(:head)).edit?
  end

  test "update? whatever their role or membership" do
    { head: :head_in_home, spouse: :spouse_in_home, eli: :eli_in_home }.each do |identity, membership|
      Current.identity = identities(identity)

      [ nil, memberships(membership) ].each do |seat|
        assert UserPolicy.new(seat, users(identity)).update?, "expected #{identity} to edit their own profile"
      end
    end
  end

  test "update? is false with nobody signed in" do
    assert_not UserPolicy.new(nil, users(:head)).update?
  end
end
