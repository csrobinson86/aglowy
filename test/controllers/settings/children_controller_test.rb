require "test_helper"

# Settings → Children: the meeting helper switch for heads and adults, and personal study with AI per child, which only
# a head changes (docs/design/settings.md; docs/design/personal-study.md, Children).
class Settings::ChildrenControllerTest < ActionDispatch::IntegrationTest
  setup { @home = households(:home) }

  test "a head sees the meeting helper switch and can turn on personal study with AI" do
    sign_in identities(:head)

    get household_settings_children_path(household_id: @home)

    assert_response :success
    assert_select "title", "Children · Settings · The Head Family · Aglowy"
    assert_select "main h2", "Children"
    assert_select "main p", "The Head Family · heads and adults; AI for a child is heads only."
    assert_select "nav[aria-label='Settings'] a[aria-current=page]", "Children"
    assert_select "form[action=?] input[type=checkbox][name=?]:not([checked])", household_settings_meeting_helper_path(household_id: @home), "meeting_helper[enabled]"
    assert_select "#study-ai form[action=?]", household_membership_study_ai_grant_path(household_id: @home, membership_id: memberships(:eli_in_home))
    assert_no_match "Turned on by", response.body
    assert_no_match "Only a head can turn this on.", response.body
  end

  test "an adult sees the meeting helper switch and the AI state, but can't change the AI" do
    memberships(:eli_in_home).grant_study_ai(by: users(:head))
    sign_in identities(:spouse)

    get household_settings_children_path(household_id: @home)

    assert_response :success
    assert_select "form[action=?]", household_settings_meeting_helper_path(household_id: @home)
    assert_select "#study-ai .Label", text: "On"
    assert_select "#study-ai form", count: 0
    assert_select "#study-ai p", text: "Only a head can turn this on."
  end

  test "when the helper is on, the box is ticked and says who turned it on, on the date where the household lives" do
    @home.update!(time_zone: "Central Time (US & Canada)")
    # 2:00 AM UTC on November 16 is still the evening of November 15 in Chicago.
    travel_to(Time.utc(2026, 11, 16, 2)) { @home.enable_meeting_helper(by: users(:spouse)) }
    sign_in identities(:head)

    get household_settings_children_path(household_id: @home)

    assert_select "input[type=checkbox][name=?][checked]", "meeting_helper[enabled]"
    assert_select "main p", text: "Turned on by Sam Spouse on November 15."
  end

  test "a child is refused" do
    sign_in identities(:eli)

    get household_settings_children_path(household_id: @home)

    assert_redirected_to household_root_path(household_id: @home)
    assert_equal "You can't do that in this household.", flash[:alert]
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)

    get household_settings_children_path(household_id: @home)

    assert_response :not_found
  end
end
