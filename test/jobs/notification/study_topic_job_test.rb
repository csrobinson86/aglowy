require "test_helper"

# Each day at 8 AM in the household's zone, for sessions 3 days ahead by its local date that aren't cancelled and have
# no topic, to its heads (docs/design/notifications.md, The kinds and Recurring jobs).
class Notification::StudyTopicJobTest < ActiveJob::TestCase
  CHICAGO = ActiveSupport::TimeZone["Central Time (US & Canada)"]

  setup do
    @household = households(:home)
    @household.update!(time_zone: CHICAGO.name)
  end

  test "a session 3 days out with no topic notifies the heads only" do
    session = session_on(Date.new(2026, 11, 20))

    eight_am_on_november_17 { Notification::StudyTopicJob.perform_now }

    assert_equal [ users(:head) ], Notification.where(subject: session).map(&:user)
    assert_equal "study_topic_needed:#{session.id}", Notification.find_by!(subject: session).dedupe_key
  end

  test "one with a topic, a cancelled one, and one 4 days out don't" do
    with_topic = session_on(Date.new(2026, 11, 20), topic: "Proverbs 3")
    cancelled = session_on(Date.new(2026, 11, 20)).tap(&:cancel)
    four_days_out = session_on(Date.new(2026, 11, 21))

    eight_am_on_november_17 { Notification::StudyTopicJob.perform_now }

    assert_not Notification.exists?(subject: [ with_topic, cancelled, four_days_out ])
  end

  test "not at 9 AM" do
    session = session_on(Date.new(2026, 11, 20))

    travel_to(CHICAGO.local(2026, 11, 17, 9, 10)) { Notification::StudyTopicJob.perform_now }

    assert_not Notification.exists?(subject: session)
  end

  test "twice makes one" do
    session = session_on(Date.new(2026, 11, 20))

    eight_am_on_november_17 do
      Notification::StudyTopicJob.perform_now
      Notification::StudyTopicJob.perform_now
    end

    assert_equal 1, Notification.where(subject: session).count
  end

  test "cancelling the session deletes its topic notification" do
    session = session_on(Date.new(2026, 11, 20))
    eight_am_on_november_17 { Notification::StudyTopicJob.perform_now }

    session.cancel

    assert_not Notification.exists?(subject: session)
  end

  test "one that raises is reported and the next still gets its topic question" do
    households(:parents).update!(time_zone: CHICAGO.name)
    sessions = [ @household, households(:parents) ].map { session_on(Date.new(2026, 11, 20), household: it) }
    first, second = sessions.sort_by { it.family_study.household_id }

    eight_am_on_november_17 do
      assert_error_reported { failing_delivery_for(first.family_study.household) { Notification::StudyTopicJob.perform_now } }
    end

    assert_not Notification.exists?(subject: first), "its lock's transaction rolled back"
    assert Notification.exists?(subject: second)
  end

  test "a session cancelled after the job read it isn't asked about" do
    session = session_on(Date.new(2026, 11, 20))
    FamilyStudy::Session.find(session.id).cancel

    eight_am_on_november_17 { session.ask_heads_for_topic(on: Date.new(2026, 11, 20)) }

    assert_not Notification.exists?(subject: session)
  end

  test "a session given a topic after the job read it isn't asked about" do
    session = session_on(Date.new(2026, 11, 20))
    FamilyStudy::Session.find(session.id).update!(topic: "Proverbs 3")

    eight_am_on_november_17 { session.ask_heads_for_topic(on: Date.new(2026, 11, 20)) }

    assert_not Notification.exists?(subject: session)
  end

  test "a session moved to another day after the job read it isn't asked about" do
    session = session_on(Date.new(2026, 11, 20))
    FamilyStudy::Session.find(session.id).reschedule(on: Date.new(2026, 11, 21), at: Time.zone.parse("19:00"))

    eight_am_on_november_17 { session.ask_heads_for_topic(on: Date.new(2026, 11, 20)) }

    assert_not Notification.exists?(subject: session)
  end

  private
    def session_on(date, topic: nil, household: @household)
      travel_to(CHICAGO.local(2026, 11, 16)) do
        household.schedule_family_study(topic:, frequency: "once", starts_on: date, time_of_day: "19:00").first_session
      end
    end

    def eight_am_on_november_17(&)
      travel_to(CHICAGO.local(2026, 11, 17, 8, 10), &)
    end
end
