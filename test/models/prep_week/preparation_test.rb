require "test_helper"

# The claim that a run is asking the AI for a household's Get ready week (docs/design/meeting-prep.md, The weekly AI
# job). Taking it, holding it and letting it go are tested through household.prepare_meeting_prep, in
# test/models/household/meeting_prep_preparable_test.rb.
class PrepWeek::PreparationTest < ActiveSupport::TestCase
  WEEK = Date.new(2026, 11, 16)

  setup { @claim = PrepWeek::Preparation.create!(household: households(:home), week_of: WEEK, token: SecureRandom.uuid) }

  test "deleting the household deletes its claims" do
    households(:home).destroy!

    assert_not PrepWeek::Preparation.exists?(@claim.id)
  end

  test "database: a second claim for the same household and week" do
    assert_raises ActiveRecord::RecordNotUnique do
      PrepWeek::Preparation.insert!({ household_id: households(:home).id, week_of: WEEK, token: SecureRandom.uuid, created_at: Time.current })
    end
  end

  test "database: a claim without a token" do
    assert_raises(ActiveRecord::NotNullViolation) { @claim.update_column(:token, nil) }
  end
end
