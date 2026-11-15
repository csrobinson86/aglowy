require "test_helper"

# Signing-in details are outside any household, so the membership is nil there (docs/design/invitations.md, Account settings).
class IdentityPolicyTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "update? and edit? only for the signed-in login itself" do
    Current.identity = identities(:spouse)

    assert IdentityPolicy.new(nil, identities(:spouse)).update?
    assert IdentityPolicy.new(nil, identities(:spouse)).edit?
    assert_not IdentityPolicy.new(nil, identities(:head)).update?
    assert_not IdentityPolicy.new(nil, identities(:head)).edit?
  end

  test "update? whatever their role or membership" do
    { head: :head_in_home, spouse: :spouse_in_home, eli: :eli_in_home }.each do |identity, membership|
      Current.identity = identities(identity)

      [ nil, memberships(membership) ].each do |seat|
        assert IdentityPolicy.new(seat, identities(identity)).update?, "expected #{identity} to edit their own sign-in details"
      end
    end
  end

  test "update? is false with nobody signed in" do
    assert_not IdentityPolicy.new(nil, identities(:head)).update?
  end

  # Children see their username read-only and only the password fields.
  test "permitted_attributes: email only for a login that has one" do
    assert_equal %i[ email password current_password ], IdentityPolicy.new(nil, identities(:head)).permitted_attributes
    assert_equal %i[ password current_password ], IdentityPolicy.new(nil, identities(:eli)).permitted_attributes
  end
end
