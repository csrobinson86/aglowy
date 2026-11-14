require "test_helper"

class HouseholdTest < ActiveSupport::TestCase
  test "requires a name" do
    household = Household.new(name: "")

    assert_not household.valid?
    assert_includes household.errors[:name], "can't be blank"
  end

  test "rejects an unknown time zone" do
    household = Household.new(name: "The Lees", time_zone: "Mars/Olympus Mons")

    assert_not household.valid?
    assert_includes household.errors[:time_zone], "is not included in the list"
  end

  test "create_with_head creates the household and a head membership" do
    household = Household.create_with_head(household: { name: "The Newcomers" }, head: users(:newcomer))

    assert household.persisted?
    assert_equal [ [ users(:newcomer), "head" ] ], household.memberships.map { [ it.user, it.role ] }
  end

  test "create_with_head creates nothing when the head membership is invalid" do
    assert_no_difference [ "Household.count", "Membership.count" ] do
      assert_raises ActiveRecord::RecordInvalid do
        Household.create_with_head(household: { name: "The Nobodies" }, head: nil)
      end
    end
  end

  test "add_member creates a user with no identity and a membership with the given role" do
    membership = households(:home).add_member(name: "Baby Head", role: :child)

    assert membership.persisted?
    assert membership.child?
    assert_equal "Baby Head", membership.user.name
    assert_nil membership.user.identity
  end

  test "add_member with a blank name raises RecordInvalid and creates nothing" do
    assert_no_difference [ "User.count", "Membership.count" ] do
      assert_raises ActiveRecord::RecordInvalid do
        households(:home).add_member(name: " ", role: :child)
      end
    end
  end

  test "add_member refuses the head role" do
    assert_raises ArgumentError do
      households(:home).add_member(name: "Second Head", role: :head)
    end
  end

  test "database: a household without a name raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      Household.insert!({ name: nil })
    end
  end
end
