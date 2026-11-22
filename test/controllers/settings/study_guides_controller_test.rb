require "test_helper"

# Settings → You → Study guide, for a head or adult in any active household (docs/design/study-guide.md, The Settings
# section; docs/design/settings.md, The section nav). Hannah is a head in home, Sam an adult, Eli a child only.
class Settings::StudyGuidesControllerTest < ActionDispatch::IntegrationTest
  setup { @home = households(:home) }

  test "a head sees the section: its title, note, the check box with its caption, and Save" do
    users(:head).accept_ai_terms(understood: "1")
    sign_in identities(:head)

    get household_settings_study_guide_path(household_id: @home)

    assert_response :success
    assert_select "main h2", "Study guide"
    assert_select "main", text: /You · in every household where you're a head or an adult\./
    assert_select "nav[aria-label='Settings'] a[aria-current=page]", "Study guide"
    assert_select "main h3", "Weekly study guide"
    assert_select "form[action=?] input[type=checkbox][name='study_guide[enabled]']:not([checked]):not([disabled])", household_settings_study_guide_path(household_id: @home)
    assert_select "label", "Make me a study guide each week"
    assert_select "main", text: /Ready early on Monday: for each part of both meetings, what it's about and what it teaches about Jehovah, the Bible reading, ideas for Spiritual Gems comments and notes for the studies\. AI writes it from this week's program on jw\.org, in its own words\. Only you see it\./
    assert_select "button[type=submit]", "Save"
    assert_select "a[href=?]", new_household_family_study_path(household_id: @home), count: 0
  end

  test "a head turns it on and off" do
    users(:head).accept_ai_terms(understood: "1")
    sign_in identities(:head)

    patch household_settings_study_guide_path(household_id: @home), params: { study_guide: { enabled: "1" } }

    assert_redirected_to household_settings_study_guide_path(household_id: @home)
    assert_equal "Study guide turned on.", flash[:notice]
    assert users(:head).reload.study_guide_on?
    follow_redirect!
    assert_select "input[type=checkbox][name='study_guide[enabled]'][checked]"

    patch household_settings_study_guide_path(household_id: @home), params: { study_guide: { enabled: "0" } }

    assert_redirected_to household_settings_study_guide_path(household_id: @home)
    assert_equal "Study guide turned off.", flash[:notice]
    assert_not users(:head).reload.study_guide_on?
  end

  test "an adult turns it on and off" do
    users(:spouse).accept_ai_terms(understood: "1")
    sign_in identities(:spouse)

    patch household_settings_study_guide_path(household_id: @home), params: { study_guide: { enabled: "1" } }

    assert_redirected_to household_settings_study_guide_path(household_id: @home)
    assert users(:spouse).reload.study_guide_on?

    patch household_settings_study_guide_path(household_id: @home), params: { study_guide: { enabled: "0" } }

    assert_redirected_to household_settings_study_guide_path(household_id: @home)
    assert_not users(:spouse).reload.study_guide_on?
  end

  test "a child-only person gets a 404, and the nav leaves the section out" do
    sign_in identities(:eli)

    get household_settings_profile_path(household_id: @home)
    assert_select "a[href=?]", household_settings_study_guide_path(household_id: @home), count: 0

    get household_settings_study_guide_path(household_id: @home)
    assert_response :not_found

    patch household_settings_study_guide_path(household_id: @home), params: { study_guide: { enabled: "1" } }
    assert_response :not_found
    assert_not User::WeeklyStudyGuide.exists?(user: users(:eli))
  end

  # The section is the person's, not this seat's (docs/design/study-guide.md, Who can do what).
  test "a child here who is an adult in another household sees the section here" do
    users(:eli).memberships.create!(household: households(:parents), role: "adult")
    sign_in identities(:eli)

    get household_settings_study_guide_path(household_id: @home)

    assert_response :success
    assert_select "nav[aria-label='Settings'] a[aria-current=page]", "Study guide"
  end

  test "without accepted AI terms the check box is disabled, with a line linking to where they're accepted, and no Save" do
    sign_in identities(:spouse)

    get household_settings_study_guide_path(household_id: @home)

    assert_response :success
    assert_select "input[type=checkbox][name='study_guide[enabled]'][disabled]"
    assert_select "main", text: /Turn on AI features first\. You can do it from Draft with AI when you schedule a family study\./
    assert_select "main a[href=?]", new_household_family_study_path(household_id: @home), text: "Schedule a family study"
    assert_select "button[type=submit]", text: "Save", count: 0
  end

  test "without accepted AI terms the update saves nothing" do
    sign_in identities(:spouse)

    patch household_settings_study_guide_path(household_id: @home), params: { study_guide: { enabled: "1" } }

    assert_response :unprocessable_content
    assert_not User::WeeklyStudyGuide.exists?(user: users(:spouse))
    assert_select "input[type=checkbox][name='study_guide[enabled]'][disabled]"
  end

  test "another household's URL is a 404" do
    sign_in identities(:head)

    get household_settings_study_guide_path(household_id: households(:other))

    assert_response :not_found
  end
end
