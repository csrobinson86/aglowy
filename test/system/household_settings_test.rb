require "application_system_test_case"

class HouseholdSettingsTest < ApplicationSystemTestCase
  test "a head changes the name and sees it in the switcher" do
    sign_in identities(:head)
    visit household_root_url(household_id: households(:home))

    click_on "Household settings"

    assert_selector "h1", text: "Household settings"
    assert_text "Changing it keeps each study at the same local time."
    assert_accessible
    capture_screens("household-settings")

    fill_in "Name", with: "The Rivera Family"
    select "(GMT-06:00) Central Time (US & Canada)", from: "Time zone"
    within("#name-and-time-zone") { click_on "Save" }

    assert_text "Household settings saved."
    assert_selector "aside nav a[aria-current=page]", text: "Household settings"
    find("aside button[aria-haspopup='true']", text: "The Rivera Family").click
    assert_selector "action-menu [role='menu'] [aria-checked=true]", text: "The Rivera Family", visible: true
    assert_title "Household settings · The Rivera Family · Aglowy"
  end

  test "an adult sets the meeting times and sees them saved" do
    sign_in identities(:spouse)
    visit household_root_url(household_id: households(:home))

    click_on "Household settings"

    assert_selector "h1", text: "Household settings"
    assert_text "A head changes the household's name, time zone and roles."
    assert_no_selector "h2", text: "Members and roles"
    select "Friday", from: "Midweek day"
    fill_in "Midweek starts at", with: Time.zone.parse("19:00")
    select "Sunday", from: "Weekend day"
    fill_in "Weekend starts at", with: Time.zone.parse("10:00")
    assert_accessible
    capture_screens("household-settings-adult")
    within("#meetings") { click_on "Save" }

    assert_text "Meeting times saved."
    assert_select "Midweek day", selected: "Friday"
    assert_field "Midweek starts at", with: "19:00"
    assert_select "Weekend day", selected: "Sunday"
    assert_field "Weekend starts at", with: "10:00"
    assert_accessible
  end

  test "an adult turns the helper on and sees who turned it on" do
    sign_in identities(:spouse)
    visit edit_household_settings_url(household_id: households(:home))

    check "Meeting helper for children"
    within("#children") { click_on "Save" }

    assert_text "Meeting helper turned on."
    assert_checked_field "Meeting helper for children"
    assert_text "Turned on by Sam Spouse on #{Time.current.strftime("%B %-d")}."
    assert_accessible
    capture_screens("household-settings-meeting-helper", scroll_to: "#children")

    uncheck "Meeting helper for children"
    within("#children") { click_on "Save" }

    assert_text "Meeting helper turned off."
    assert_no_checked_field "Meeting helper for children"
    assert_no_text "Turned on by"
  end
end
