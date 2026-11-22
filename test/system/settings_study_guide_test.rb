require "application_system_test_case"

# Settings → You → Study guide (docs/design/study-guide.md, The Settings section; frame
# docs/design/study-guide/phone-guide-settings.png). Hannah is a head in home; Sam, an adult, hasn't accepted the AI terms.
class SettingsStudyGuideTest < ApplicationSystemTestCase
  test "a head turns their study guide on and sees it saved, then turns it off" do
    users(:head).accept_ai_terms(understood: "1")
    sign_in identities(:head)
    visit household_settings_profile_url(household_id: households(:home))

    within("nav[aria-label='Settings']") { click_on "Study guide" }
    assert_selector "h2", text: "Study guide"
    assert_selector "nav[aria-label='Settings'] a[aria-current=page]", text: "Study guide"
    assert_text "You · in every household where you're a head or an adult."
    assert_unchecked_field "Make me a study guide each week"

    check "Make me a study guide each week"
    click_on "Save"

    assert_text "Study guide turned on."
    assert_checked_field "Make me a study guide each week"
    assert users(:head).reload.study_guide_on?
    assert_accessible
    capture_screens("settings-study-guide")

    uncheck "Make me a study guide each week"
    click_on "Save"
    assert_text "Study guide turned off."
    assert_unchecked_field "Make me a study guide each week"
    assert_not users(:head).reload.study_guide_on?
  end

  test "without accepted AI terms the check box is disabled, with a link to where they're accepted" do
    sign_in identities(:spouse)
    visit household_settings_study_guide_url(household_id: households(:home))

    assert_field "Make me a study guide each week", disabled: true, checked: false
    assert_text "Turn on AI features first. You can do it from Draft with AI when you schedule a family study."
    assert_no_button "Save"
    assert_accessible
    capture_screens("settings-study-guide-no-terms")

    click_on "Schedule a family study"
    assert_current_path new_household_family_study_path(household_id: households(:home))
  end
end
