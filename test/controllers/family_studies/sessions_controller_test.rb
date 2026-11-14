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
    assert_select "a[href='#{edit_household_family_study_session_notes_path(household_id: households(:home), family_study_id: study_session.family_study, session_id: study_session)}']", text: "Edit notes"
  end

  test "notes are shown through Action Text, sanitized" do
    study_session = family_study_sessions(:weekly_next)
    study_session.update!(notes: %(<p>Read <strong>Ruth 1</strong></p><script>alert("hi")</script><embed src="https://example.com/x.html"><video src="https://example.com/v.mp4"></video>))
    sign_in identities(:spouse)

    get session_path(study_session)

    assert_select "main .lexxy-content strong", "Ruth 1"
    assert_select "main script", text: /alert/, count: 0
    assert_select "main embed, main video", count: 0
    assert_select "main .blankslate", text: /No notes yet/, count: 0
  end

  test "a child reads the notes but gets no Edit notes button" do
    study_session = family_study_sessions(:weekly_next)
    study_session.update!(notes: "<p>Read Ruth 1</p>")
    sign_in child_identity

    get session_path(study_session)

    assert_select "main .lexxy-content", text: "Read Ruth 1"
    assert_select "a", text: "Edit notes", count: 0
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
    assert_select "a", text: "Edit notes", count: 0
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

  test "a head and an adult see Edit this session and Cancel this session" do
    study_session = family_study_sessions(:weekly_next)

    %i[ head spouse ].each do |identity|
      sign_in identities(identity)
      get session_path(study_session)

      assert_select "a[href='#{edit_session_path(study_session)}']", text: "Edit this session"
      assert_select "button[data-show-dialog-id]", text: "Cancel this session"
      assert_select "dialog form[action='#{cancellation_path(study_session)}'][method='post'] button[type='submit']", text: "Cancel this session"
      assert_select "button", text: "Restore this session", count: 0
    end
  end

  test "a cancelled session offers Restore this session instead of Cancel" do
    study_session = family_study_sessions(:weekly_cancelled)
    sign_in identities(:spouse)

    get session_path(study_session)

    assert_select "form[action='#{cancellation_path(study_session)}'] input[name='_method'][value='delete']"
    assert_select "button[type='submit']", text: "Restore this session"
    assert_select "button", text: "Cancel this session", count: 0
  end

  test "a child gets no Edit, Cancel or Restore buttons" do
    sign_in child_identity

    get session_path(family_study_sessions(:weekly_next))
    assert_select "a", text: "Edit this session", count: 0
    assert_select "button", text: "Cancel this session", count: 0

    get session_path(family_study_sessions(:weekly_cancelled))
    assert_select "button", text: "Restore this session", count: 0
  end

  test "a head and an adult can edit a session" do
    study_session = family_study_sessions(:one_off_first)

    %i[ head spouse ].each do |identity|
      sign_in identities(identity)
      get edit_session_path(study_session)

      assert_response :success
      assert_select "h1", "Edit this session"
      assert_select "input[name='family_study_session_edit[topic]'][value='Draw Close to Jehovah, chapter 1']"
      assert_select "input[type='date'][name='family_study_session_edit[starts_on]'][value='#{study_session.local_scheduled_at.to_date.iso8601}']"
      assert_select "input[type='time'][name='family_study_session_edit[starts_at]'][value='19:00']"
      assert_select "form", text: /Changes this session only\./
    end
  end

  test "a head reschedules a session" do
    study_session = family_study_sessions(:weekly_next)
    new_day = study_session.local_scheduled_at.to_date + 2
    sign_in identities(:head)

    patch update_session_path(study_session), params: { family_study_session_edit: { topic: "Ruth 2", starts_on: new_day.iso8601, starts_at: "18:30" } }

    assert_redirected_to session_path(study_session)
    assert_equal "Session updated.", flash[:notice]
    study_session.reload
    assert_equal "Ruth 2", study_session.topic
    assert_equal Time.zone.local(new_day.year, new_day.month, new_day.day, 18, 30), study_session.scheduled_at
    assert study_session.detached_at
  end

  test "an adult changes only the topic" do
    study_session = family_study_sessions(:weekly_next)
    local = study_session.local_scheduled_at
    sign_in identities(:spouse)

    patch update_session_path(study_session), params: { family_study_session_edit: { topic: "Ruth 3", starts_on: local.to_date.iso8601, starts_at: local.strftime("%H:%M") } }

    assert_redirected_to session_path(study_session)
    assert_equal "Ruth 3", study_session.reload.topic
    assert_nil study_session.detached_at
  end

  test "an edit without a date shows the error with the field" do
    study_session = family_study_sessions(:weekly_next)
    sign_in identities(:head)

    patch update_session_path(study_session), params: { family_study_session_edit: { topic: "Ruth 2", starts_on: "", starts_at: "18:30" } }

    assert_response :unprocessable_content
    assert_select "input[name='family_study_session_edit[starts_on]'][aria-invalid='true']"
    assert_select ".FormControl-inlineValidation", text: /can't be blank/
    assert_nil study_session.reload.topic
  end

  test "a child can't edit a session" do
    study_session = family_study_sessions(:weekly_next)
    scheduled_at = study_session.scheduled_at
    sign_in child_identity

    get edit_session_path(study_session)
    assert_redirected_to household_root_path(household_id: households(:home))

    patch update_session_path(study_session), params: { family_study_session_edit: { topic: "Mine now", starts_on: "2030-01-01", starts_at: "09:00" } }
    assert_redirected_to household_root_path(household_id: households(:home))
    study_session.reload
    assert_nil study_session.topic
    assert_equal scheduled_at, study_session.scheduled_at
  end

  test "editing another household's session gets 404" do
    outsiders_session = households(:other).schedule_family_study(frequency: :once, starts_on: 2.days.from_now.to_date, time_of_day: "18:00").sessions.sole

    sign_in identities(:head)
    get edit_household_family_study_session_path(household_id: households(:home), family_study_id: outsiders_session.family_study, id: outsiders_session)
    assert_response :not_found

    # The 404 response doesn't carry the session cookie, so sign in again.
    sign_in identities(:head)
    patch household_family_study_session_path(household_id: households(:home), family_study_id: family_studies(:weekly), id: outsiders_session),
          params: { family_study_session_edit: { topic: "Hello", starts_on: "2030-01-01", starts_at: "09:00" } }
    assert_response :not_found
    assert_nil outsiders_session.reload.topic
  end

  private
    def session_path(study_session)
      household_family_study_session_path(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)
    end

    def edit_session_path(study_session)
      edit_household_family_study_session_path(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)
    end

    def update_session_path(study_session)
      session_path(study_session)
    end

    def cancellation_path(study_session)
      household_family_study_session_cancellation_path(household_id: households(:home), family_study_id: study_session.family_study, session_id: study_session)
    end

    # Charlie Child has no login in the fixtures, so give them one here.
    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
