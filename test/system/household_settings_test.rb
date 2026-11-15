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
    click_on "Save"

    assert_text "Meeting times saved."
    assert_select "Midweek day", selected: "Friday"
    assert_field "Midweek starts at", with: "19:00"
    assert_select "Weekend day", selected: "Sunday"
    assert_field "Weekend starts at", with: "10:00"
    assert_accessible
  end
end
