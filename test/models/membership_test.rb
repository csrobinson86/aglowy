require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "role defaults to adult" do
    assert Membership.new.adult?
  end

  test "by_household_name orders by the household's name" do
    assert_equal [ households(:parents), households(:home) ], users(:head).memberships.by_household_name.map(&:household)
  end

  test "an unknown role is a validation error, not an ArgumentError" do
    membership = Membership.new(household: households(:home), user: users(:newcomer), role: "admin")

    assert_not membership.valid?
    assert_includes membership.errors[:role], "is not included in the list"
  end

  test "database: role admin raises CheckViolation" do
    assert_raises ActiveRecord::CheckViolation do
      Membership.insert!({ household_id: households(:home).id, user_id: users(:newcomer).id, role: "admin" })
    end
  end

  test "database: the same person twice in one household raises RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      Membership.insert!({ household_id: households(:home).id, user_id: users(:head).id })
    end
  end

  test "database: a membership for a missing household raises InvalidForeignKey" do
    assert_raises ActiveRecord::InvalidForeignKey do
      Membership.insert!({ household_id: SecureRandom.uuid_v7, user_id: users(:newcomer).id })
    end
  end

  test "sole_head? is true for the only active head" do
    assert memberships(:head_in_home).sole_head?
  end

  test "sole_head? is false with another active head" do
    memberships(:spouse_in_home).update!(role: :head)

    assert_not memberships(:head_in_home).sole_head?
  end

  test "sole_head? is false for adults" do
    assert_not memberships(:spouse_in_home).sole_head?
  end

  test "an inactive head doesn't count" do
    memberships(:former_in_home).update!(role: :head)

    assert memberships(:head_in_home).sole_head?
  end

  test "deactivate refuses the sole head" do
    membership = memberships(:head_in_home)

    assert_not membership.deactivate
    assert membership.reload.active?
    assert_includes membership.errors[:base], "A household needs at least one active head"
  end

  test "deactivate works for an adult" do
    assert memberships(:spouse_in_home).deactivate
    assert_not memberships(:spouse_in_home).reload.active?
  end

  test "change_role refuses to demote the sole head" do
    membership = memberships(:head_in_home)

    assert_not membership.change_role(:adult)
    assert membership.reload.head?
    assert_includes membership.errors[:base], "A household needs at least one active head"
  end

  test "change_role demotes a head when another active head exists" do
    memberships(:spouse_in_home).update!(role: :head)

    assert memberships(:head_in_home).change_role(:adult)
    assert memberships(:head_in_home).reload.adult?
  end

  test "deactivate locks the household row" do
    assert_queries_match(/FOR UPDATE/) { memberships(:spouse_in_home).deactivate }
  end

  test "change_role locks the household row" do
    assert_queries_match(/FOR UPDATE/) { memberships(:spouse_in_home).change_role(:child) }
  end
end
