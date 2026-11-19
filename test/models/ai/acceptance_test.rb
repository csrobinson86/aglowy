require "test_helper"

class Ai::AcceptanceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "accepting with the box ticked records the current terms version" do
    acceptance = users(:head).accept_ai_terms(understood: "1")

    assert_predicate acceptance, :persisted?
    assert_equal Rails.configuration.x.ai.terms_version, acceptance.version
    assert_predicate users(:head), :accepted_ai_terms?
  end

  test "accepting without the box ticked records nothing" do
    acceptance = users(:head).accept_ai_terms(understood: "0")

    assert_not acceptance.persisted?
    assert_equal [ "Tick “I understand how AI drafts work” to turn on AI drafts" ], acceptance.errors[:understood]
    assert_not users(:head).accepted_ai_terms?
  end

  test "accepting twice keeps one record" do
    users(:head).accept_ai_terms(understood: "1")

    assert_no_difference -> { Ai::Acceptance.count } do
      assert_predicate users(:head).accept_ai_terms(understood: "1"), :persisted?
    end
  end

  test "the database refuses a second acceptance of the same version" do
    acceptance = users(:head).accept_ai_terms(understood: "1")

    assert_raises(ActiveRecord::RecordNotUnique) { Ai::Acceptance.insert!({ user_id: acceptance.user_id, version: acceptance.version }) }
  end

  test "the database refuses an acceptance without a version" do
    acceptance = users(:head).accept_ai_terms(understood: "1")

    assert_raises(ActiveRecord::NotNullViolation) { acceptance.update_column(:version, nil) }
  end

  test "the database refuses an acceptance without a person" do
    acceptance = users(:head).accept_ai_terms(understood: "1")

    assert_raises(ActiveRecord::NotNullViolation) { acceptance.update_column(:user_id, nil) }
  end

  test "the database refuses an acceptance for someone who doesn't exist" do
    acceptance = users(:head).accept_ai_terms(understood: "1")

    assert_raises(ActiveRecord::InvalidForeignKey) { acceptance.update_column(:user_id, SecureRandom.uuid_v7) }
  end

  LISTENING_GAME_MONDAY = Time.utc(2026, 11, 16, 9)

  # Accepting the AI terms prepares the week (docs/design/listening-game.md, When it runs). Monday 16 November 2026, with
  # the midweek meeting on Tuesday at 7pm.
  test "an adult accepting the AI terms enqueues the preparation for a household with the helper on and no game" do
    listening_game_week(households(:home))

    assert_enqueued_with(job: ListeningGame::PrepareJob, args: [ households(:home) ]) do
      travel_to(LISTENING_GAME_MONDAY) { users(:spouse).accept_ai_terms(understood: "1") }
    end
  end

  test "accepting enqueues no preparation for a household with the helper off" do
    listening_game_week(households(:home)).disable_meeting_helper

    assert_no_listening_game_prepared { users(:spouse).accept_ai_terms(understood: "1") }
  end

  test "accepting enqueues no preparation for a household that has this week's game" do
    ListeningGame.create!(household: listening_game_week(households(:home)), week_of: Date.new(2026, 11, 16))

    assert_no_listening_game_prepared { users(:spouse).accept_ai_terms(understood: "1") }
  end

  test "accepting enqueues no preparation for a household where they're a child" do
    listening_game_week(households(:home))

    assert_no_listening_game_prepared { users(:child).accept_ai_terms(understood: "1") }
  end

  test "nothing is enqueued when the acceptance's transaction rolls back" do
    listening_game_week(households(:home))

    assert_no_listening_game_prepared do
      Ai::Acceptance.transaction do
        users(:spouse).accept_ai_terms(understood: "1")
        raise ActiveRecord::Rollback
      end
    end
  end

  private
    # The helper on, meeting on Tuesdays, and nothing enqueued yet.
    def listening_game_week(household)
      household.change_meeting_times(midweek_wday: 2, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
      household.enable_meeting_helper(by: users(:head))
      clear_enqueued_jobs
      household
    end

    def assert_no_listening_game_prepared(&)
      assert_no_enqueued_jobs(only: ListeningGame::PrepareJob) { travel_to(LISTENING_GAME_MONDAY, &) }
    end
end
