require "test_helper"

# The claim that a run is asking the AI for a household's week (docs/design/listening-game.md, Models). Taking it,
# holding it and letting it go are tested through the job, in test/jobs/listening_game/prepare_job_test.rb.
class ListeningGame::PreparationTest < ActiveSupport::TestCase
  WEEK = Date.new(2026, 11, 16)

  setup { @claim = ListeningGame::Preparation.create!(household: households(:home), week_of: WEEK, token: SecureRandom.uuid) }

  test "deleting the household deletes its claims" do
    households(:home).destroy!

    assert_not ListeningGame::Preparation.exists?(@claim.id)
  end

  test "database: a second claim for the same household and week raises RecordNotUnique" do
    assert_raises ActiveRecord::RecordNotUnique do
      ListeningGame::Preparation.insert!({ household_id: households(:home).id, week_of: WEEK, token: SecureRandom.uuid, created_at: Time.current })
    end
  end

  test "database: a claim without a household raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { @claim.update_column(:household_id, nil) }
  end

  test "database: a household that doesn't exist raises InvalidForeignKey" do
    assert_raises(ActiveRecord::InvalidForeignKey) { @claim.update_column(:household_id, SecureRandom.uuid_v7) }
  end

  test "database: a claim without a week raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { @claim.update_column(:week_of, nil) }
  end

  test "database: a claim without a token raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { @claim.update_column(:token, nil) }
  end

  test "database: a claim without created_at raises NotNullViolation" do
    assert_raises(ActiveRecord::NotNullViolation) { @claim.update_column(:created_at, nil) }
  end
end
