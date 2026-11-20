require "application_system_test_case"

# Settings → Children: the Get ready check box under the meeting helper's, shown only while the helper is on
# (docs/design/meeting-prep.md, The Settings check box; frame docs/design/meeting-prep/phone-prep-settings.png).
class SettingsChildrenTest < ApplicationSystemTestCase
  test "an adult turns the helper on, then Get ready, and sees who turned it on" do
    sign_in identities(:spouse)
    visit household_settings_children_url(household_id: households(:home))

    assert_unchecked_field "Meeting helper for children"
    assert_no_field "Get ready cards"
    check "Meeting helper for children"
    click_on "Save"
    assert_text "Meeting helper turned on."

    assert_unchecked_field "Get ready cards"
    assert_text "Each week, AI writes a few simple cards about both meetings"
    check "Get ready cards"
    click_on "Save"

    assert_text "Meeting helper and Get ready cards turned on."
    assert_checked_field "Get ready cards"
    turned_on = "Turned on by Sam Spouse on #{Time.current.in_time_zone(households(:home).time_zone).strftime("%B %-d")}."
    within(".FormControl-checkbox-wrap", text: "Get ready cards") { assert_text turned_on }
    assert households(:home).reload.meeting_prep?
    assert_accessible
    capture_screens("settings-children-prep", scroll_to: "input[type=checkbox][name='meeting_helper[meeting_prep]']")

    uncheck "Meeting helper for children"
    click_on "Save"
    assert_text "Meeting helper turned off."
    assert_no_field "Get ready cards"
    assert_not households(:home).reload.meeting_prep?
  end
end
