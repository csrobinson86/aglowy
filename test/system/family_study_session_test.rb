require "application_system_test_case"

class FamilyStudySessionTest < ApplicationSystemTestCase
  test "open a session from the list" do
    sign_in identities(:head)
    visit household_family_studies_url(household_id: households(:home))

    click_on "Draw Close to Jehovah, chapter 1"

    assert_selector "h1", text: "Draw Close to Jehovah, chapter 1"
    assert_selector ".Subhead-description", text: "Once"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Family studies"
    assert_selector "h2", text: "Notes"
    assert_selector "h2", text: "Resources"
    assert_accessible
    capture_screens("study-session")
  end

  test "a cancelled session with no topic passes assert_accessible" do
    study_session = family_study_sessions(:weekly_cancelled)
    sign_in identities(:head)

    visit household_family_study_session_url(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)

    assert_selector "h1", text: "Family study"
    assert_selector ".Label", text: "Cancelled"
    assert_accessible
    capture_screens("study-session-cancelled")
  end
end
