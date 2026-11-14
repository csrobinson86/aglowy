require "test_helper"

class SignupTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  FOUR_ROWS = %w[ Identity.count User.count Household.count Membership.count ]

  test "a valid sign-up creates exactly one Identity, User, Household and head Membership" do
    signup = Signup.new(valid_attributes)

    assert_difference FOUR_ROWS, 1 do
      assert signup.save
    end

    membership = Identity.find_by!(email: "rosa@example.com").user.memberships.sole
    assert membership.head?
    assert_equal "The Robinson Family", membership.household.name
    assert_equal "London", membership.household.time_zone
  end

  test "a duplicate email creates none of the four and exposes the email error" do
    signup = Signup.new(valid_attributes.merge(email: identities(:head).email))

    assert_no_difference FOUR_ROWS do
      assert_not signup.save
    end

    assert_includes signup.errors[:email], "has already been taken"
  end

  test "a missing household name is invalid and creates nothing" do
    signup = Signup.new(valid_attributes.merge(household_name: ""))

    assert_no_difference FOUR_ROWS do
      assert_not signup.save
    end

    assert_includes signup.errors[:household_name], "can't be blank"
  end

  test "a valid sign-up sends one confirmation email" do
    assert_emails 1 do
      Signup.new(valid_attributes).save
    end
  end

  # The User and Identity are written before the Household fails, so this
  # proves Devise's after_commit mail doesn't go out for a rolled-back sign-up.
  test "an invalid sign-up sends none" do
    signup = Signup.new(valid_attributes.merge(time_zone: "Mars/Olympus Mons"))

    assert_no_emails do
      assert_not signup.save
    end

    assert_includes signup.errors[:time_zone], "is not included in the list"
  end

  private

  def valid_attributes
    { name: "Rosa Robinson", email: "rosa@example.com", password: "password123",
      household_name: "The Robinson Family", time_zone: "London" }
  end
end
