require "test_helper"

class FamilyStudies::Sessions::CancellationsControllerTest < ActionDispatch::IntegrationTest
  test "a head and an adult can cancel a session and restore it" do
    study_session = family_study_sessions(:weekly_next)

    %i[ head spouse ].each do |identity|
      sign_in identities(identity)

      post cancellation_path(study_session)
      assert_redirected_to session_path(study_session)
      assert_equal "Session cancelled.", flash[:notice]
      assert_predicate study_session.reload, :canceled?

      delete cancellation_path(study_session)
      assert_redirected_to session_path(study_session)
      assert_equal "Session restored.", flash[:notice]
      assert_not_predicate study_session.reload, :canceled?
    end
  end

  test "cancelling leaves the rest of the series alone" do
    sign_in identities(:head)

    assert_no_difference -> { family_studies(:weekly).sessions.count } do
      post cancellation_path(family_study_sessions(:weekly_next))
    end

    assert_equal [ family_study_sessions(:weekly_next), family_study_sessions(:weekly_cancelled) ], family_studies(:weekly).sessions.where.not(canceled_at: nil).order(:scheduled_at)
  end

  test "a child gets refused" do
    sign_in child_identity

    post cancellation_path(family_study_sessions(:weekly_next))
    assert_redirected_to household_root_path(household_id: households(:home))
    assert_not_predicate family_study_sessions(:weekly_next).reload, :canceled?

    delete cancellation_path(family_study_sessions(:weekly_cancelled))
    assert_redirected_to household_root_path(household_id: households(:home))
    assert_predicate family_study_sessions(:weekly_cancelled).reload, :canceled?
  end

  test "another household's session gets 404" do
    outsiders_session = households(:other).schedule_family_study(frequency: :once, starts_on: 2.days.from_now.to_date, time_of_day: "18:00").sessions.sole

    sign_in identities(:head)
    post household_family_study_session_cancellation_path(household_id: households(:home), family_study_id: outsiders_session.family_study, session_id: outsiders_session)
    assert_response :not_found

    # The 404 response doesn't carry the session cookie, so sign in again.
    sign_in identities(:head)
    delete household_family_study_session_cancellation_path(household_id: households(:home), family_study_id: family_studies(:weekly), session_id: outsiders_session)
    assert_response :not_found
    assert_not_predicate outsiders_session.reload, :canceled?
  end

  private
    def cancellation_path(study_session)
      household_family_study_session_cancellation_path(household_id: households(:home), family_study_id: study_session.family_study, session_id: study_session)
    end

    def session_path(study_session)
      household_family_study_session_path(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)
    end

    # Charlie Child has no login in the fixtures, so give them one here.
    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
