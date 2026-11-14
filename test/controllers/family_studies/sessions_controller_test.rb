require "test_helper"

class FamilyStudies::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "a member sees the session" do
    study_session = family_study_sessions(:weekly_next)
    study_session.update!(topic: "Imitate Their Faith, chapter 3")
    weekday = family_studies(:weekly).starts_on.strftime("%A")
    sign_in identities(:spouse)

    get session_path(study_session)

    assert_response :success
    assert_select "title", "Imitate Their Faith, chapter 3 · The Head Family · Aglowy"
    assert_select "h1", "Imitate Their Faith, chapter 3"
    assert_select ".Subhead-description", text: /#{study_session.local_scheduled_at.strftime("%A, %B %-d, %Y")}\s+·\s+7:00 – 7:45 PM\s+·\s+Weekly on #{weekday}/
    assert_select ".Subhead .Label", text: "Cancelled", count: 0
    assert_select "nav[aria-label='Breadcrumb'] a[href='#{household_family_studies_path(household_id: households(:home))}']", "Family studies"
    assert_select "nav[aria-label='Breadcrumb'] [aria-current='page']", study_session.local_scheduled_at.strftime("%b %-d, %Y")
    assert_select "main h2", text: "Notes"
    assert_select "main h2", text: "Resources"
    assert_select "main .blankslate", text: /No notes yet/
    assert_select "main .blankslate", text: /No resources yet/
  end

  test "a one-off session repeats Once and runs for the study's duration" do
    sign_in identities(:spouse)

    get session_path(family_study_sessions(:one_off_first))

    assert_select ".Subhead-description", text: /7:00 – 8:00 PM\s+·\s+Once/
  end

  test "a cancelled session with no topic is headed Family study and labelled Cancelled" do
    sign_in child_identity

    get session_path(family_study_sessions(:weekly_cancelled))

    assert_response :success
    assert_select "title", "Family study · The Head Family · Aglowy"
    assert_select "h1", "Family study"
    assert_select ".Subhead .Label", text: "Cancelled"
  end

  test "a session from another household's study is 404, even with a real study id from this household in the URL" do
    outsiders_session = households(:other).schedule_family_study(frequency: :once, starts_on: 2.days.from_now.to_date, time_of_day: "18:00").sessions.sole

    sign_in identities(:head)
    get household_family_study_session_path(household_id: households(:home), family_study_id: family_studies(:weekly), id: outsiders_session)
    assert_response :not_found

    # The 404 response doesn't carry the session cookie, so sign in again.
    sign_in identities(:head)
    get household_family_study_session_path(household_id: households(:home), family_study_id: outsiders_session.family_study, id: outsiders_session)
    assert_response :not_found
  end

  test "a session paired with another of this household's studies is 404" do
    sign_in identities(:head)

    get household_family_study_session_path(household_id: households(:home), family_study_id: family_studies(:weekly), id: family_study_sessions(:one_off_first))

    assert_response :not_found
  end

  test "a non-member gets 404" do
    sign_in identities(:outsider)

    get session_path(family_study_sessions(:weekly_next))

    assert_response :not_found
  end

  private
    def session_path(study_session)
      household_family_study_session_path(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)
    end

    # Charlie Child has no login in the fixtures, so give them one here.
    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
