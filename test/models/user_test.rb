require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "squishes the name" do
    assert_equal "Ann Lee", User.new(name: "  Ann   Lee ").name
  end

  test "first_name is the first word of the name" do
    assert_equal "Hannah", users(:head).first_name
    assert_equal "Cher", User.new(name: "Cher").first_name
  end

  test "requires a name" do
    user = User.new(name: " ")

    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "active_households excludes households where the membership is inactive" do
    assert_equal [ households(:home), households(:parents) ].sort_by(&:id), users(:head).active_households.sort_by(&:id)
    assert_empty users(:former).active_households
  end

  test "give_login makes a confirmed username-only login whose password nobody knows" do
    identity = users(:sofia).give_login(username: "Sofia.Rivera")

    assert identity.persisted?
    assert_equal "sofia.rivera", identity.username
    assert_nil identity.email
    assert identity.confirmed?
    assert identity.encrypted_password.present?
    assert_not identity.valid_password?("")
  end

  test "give_login with a taken username returns the unsaved login with the error" do
    identity = users(:sofia).give_login(username: "eli.rivera")

    assert_not identity.persisted?
    assert_includes identity.errors[:username], "has already been taken"
  end

  # Two people choosing one username at once both pass the uniqueness check in Ruby; the unique index stops the second.
  test "give_login that loses the race for a username returns the unsaved login with the error, not an exception" do
    uniqueness = Identity.validators_on(:username).grep(ActiveRecord::Validations::UniquenessValidator).sole
    uniqueness.define_singleton_method(:validate) { |_record| }

    identity = assert_no_difference(-> { Identity.count }) { users(:sofia).give_login(username: "eli.rivera") }

    assert_not identity.persisted?
    assert_includes identity.errors[:username], "has already been taken"
  ensure
    uniqueness.singleton_class.remove_method(:validate)
  end

  # Two submissions of the form at once both pass give_login? before either saves; identities.user_id stops the second.
  test "give_login for someone who got a login a moment ago returns the unsaved login with the error, not an exception" do
    identity = assert_no_difference(-> { Identity.count }) { users(:eli).give_login(username: "eli.second") }

    assert_not identity.persisted?
    assert_includes identity.errors[:username], "wasn't saved: Eli already has a login"
  end

  test "database: a user without a name raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      User.insert!({ name: nil })
    end
  end
end
