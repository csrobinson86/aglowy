require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  test "requires a user" do
    identity = Identity.new(email: "someone@example.com", password: "password123")

    assert_not identity.valid?
    assert_includes identity.errors[:user], "must exist"
  end

  test "staff defaults to false" do
    assert_equal false, Identity.new.staff
  end

  test "an unconfirmed identity is not active for authentication" do
    assert_not identities(:newcomer).active_for_authentication?
  end

  test "database: a duplicate email raises RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      Identity.insert!({ user_id: users(:child).id, email: identities(:head).email, encrypted_password: "x" })
    end
  end

  test "database: a second identity for the same user raises RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      Identity.insert!({ user_id: users(:head).id, email: "second@example.com", encrypted_password: "x" })
    end
  end
end
