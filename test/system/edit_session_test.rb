require "application_system_test_case"

class EditSessionTest < ApplicationSystemTestCase
  setup do
    sign_in identities(:head)
  end

  test "reschedule a session and see the new time in the list" do
    study_session = family_study_sessions(:one_off_first)
    moved_to = study_session.local_scheduled_at.change(hour: 18, min: 30) + 1.day
    visit session_url(study_session)

    click_on "Edit this session"
    assert_selector "h1", text: "Edit this session"
    assert_text "Changes this session only."
    assert_accessible
    capture_screens("edit-session")

    fill_in "Topic", with: "Draw Close to Jehovah, chapter 2"
    fill_in "Date", with: moved_to.to_date
    fill_in "Starts", with: Time.zone.parse("18:30")
    click_on "Save session"

    assert_text "Session updated."
    assert_selector "h1", text: "Draw Close to Jehovah, chapter 2"
    assert_selector ".Subhead-description", text: "6:30 – 7:30 PM"

    visit household_family_studies_url(household_id: households(:home))
    assert_selector ".Box-row", text: /#{Regexp.escape(I18n.l(moved_to, format: :session))}\s*Draw Close to Jehovah, chapter 2/
  end

  test "cancel and restore a session" do
    visit session_url(family_study_sessions(:weekly_next))

    click_on "Cancel this session"
    assert_selector "dialog[open]", text: "You can restore it later."
    assert_accessible
    capture_screens("cancel-session")
    within("dialog[open]") { click_on "Cancel this session" }

    assert_text "Session cancelled."
    assert_selector ".Subhead .Label", text: "Cancelled"
    assert_no_selector "dialog[open]"

    click_on "Restore this session"

    assert_text "Session restored."
    assert_no_selector ".Subhead .Label", text: "Cancelled"
    assert_selector "button", text: "Cancel this session"
  end

  test "keep a session from the dialog" do
    visit session_url(family_study_sessions(:weekly_next))

    click_on "Cancel this session"
    within("dialog[open]") { click_on "Keep it" }

    assert_no_selector "dialog[open]"
    assert_no_selector ".Subhead .Label", text: "Cancelled"
    assert_not_predicate family_study_sessions(:weekly_next).reload, :canceled?
  end

  private
    def session_url(study_session)
      household_family_study_session_url(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)
    end
end
