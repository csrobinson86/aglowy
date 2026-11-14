require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "squishes the name" do
    assert_equal "Ann Lee", User.new(name: "  Ann   Lee ").name
  end

  test "requires a name" do
    user = User.new(name: " ")

    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "database: a user without a name raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      User.insert!({ name: nil })
    end
  end
end
