require "test_helper"

class FamilyStudies::Sessions::NotesControllerTest < ActionDispatch::IntegrationTest
  test "a head sees the editor with a visible label" do
    sign_in identities(:head)

    get edit_notes_path(family_study_sessions(:weekly_next))

    assert_response :success
    assert_select "h1", "Edit notes"
    assert_select "label[for='family_study_session_notes']", "Notes"
    assert_select "lexxy-editor#family_study_session_notes[name='family_study_session[notes]']"
    assert_select "trix-editor", count: 0
  end

  test "a head can update the notes" do
    study_session = family_study_sessions(:weekly_next)
    sign_in identities(:head)

    patch notes_path(study_session), params: { family_study_session: { notes: "<p>Read Ruth 1</p>" } }

    assert_redirected_to household_family_study_session_path(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)
    assert_equal "Read Ruth 1", study_session.reload.notes.to_plain_text
  end

  test "an adult can update the notes" do
    study_session = family_study_sessions(:weekly_next)
    sign_in identities(:spouse)

    patch notes_path(study_session), params: { family_study_session: { notes: "<p>Discuss loyalty</p>" } }

    assert_redirected_to household_family_study_session_path(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)
    assert_equal "Discuss loyalty", study_session.reload.notes.to_plain_text
  end

  test "a child gets refused" do
    study_session = family_study_sessions(:weekly_next)
    sign_in child_identity

    get edit_notes_path(study_session)
    assert_redirected_to household_root_path(household_id: households(:home))

    patch notes_path(study_session), params: { family_study_session: { notes: "<p>Mine now</p>" } }
    assert_redirected_to household_root_path(household_id: households(:home))
    assert_predicate study_session.reload.notes.body, :blank?
  end

  test "another household's session gets 404" do
    outsiders_session = households(:other).schedule_family_study(frequency: :once, starts_on: 2.days.from_now.to_date, time_of_day: "18:00").sessions.sole

    sign_in identities(:head)
    patch household_family_study_session_notes_path(household_id: households(:home), family_study_id: outsiders_session.family_study, session_id: outsiders_session),
          params: { family_study_session: { notes: "<p>Hello</p>" } }
    assert_response :not_found

    # The 404 response doesn't carry the session cookie, so sign in again.
    sign_in identities(:head)
    get edit_household_family_study_session_notes_path(household_id: households(:home), family_study_id: family_studies(:weekly), session_id: outsiders_session)
    assert_response :not_found
    assert_predicate outsiders_session.reload.notes.body, :blank?
  end

  private
    def notes_path(study_session)
      household_family_study_session_notes_path(household_id: households(:home), family_study_id: study_session.family_study, session_id: study_session)
    end

    def edit_notes_path(study_session)
      edit_household_family_study_session_notes_path(household_id: households(:home), family_study_id: study_session.family_study, session_id: study_session)
    end

    # Charlie Child has no login in the fixtures, so give them one here.
    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
