require "test_helper"

class Household::MeetingHelperTest < ActiveSupport::TestCase
  test "database: the unique index on household_id rejects a second row" do
    households(:home).enable_meeting_helper(by: users(:head))

    assert_raises ActiveRecord::RecordNotUnique do
      Household::MeetingHelper.insert!({ household_id: households(:home).id, enabled_by_id: users(:spouse).id })
    end
  end

  test "database: a meeting helper without enabled_by raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      Household::MeetingHelper.insert!({ household_id: households(:home).id, enabled_by_id: nil })
    end
  end

  test "database: a meeting helper without a household raises NotNullViolation" do
    assert_raises ActiveRecord::NotNullViolation do
      Household::MeetingHelper.insert!({ household_id: nil, enabled_by_id: users(:head).id })
    end
  end

  test "database: a household that doesn't exist raises InvalidForeignKey" do
    assert_raises ActiveRecord::InvalidForeignKey do
      Household::MeetingHelper.insert!({ household_id: SecureRandom.uuid_v7, enabled_by_id: users(:head).id })
    end
  end

  test "database: an enabled_by that isn't a user raises InvalidForeignKey" do
    assert_raises ActiveRecord::InvalidForeignKey do
      Household::MeetingHelper.insert!({ household_id: households(:home).id, enabled_by_id: SecureRandom.uuid_v7 })
    end
  end
end
