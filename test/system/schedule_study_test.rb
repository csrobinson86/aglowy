require "application_system_test_case"

class ScheduleStudyTest < ApplicationSystemTestCase
  setup do
    sign_in identities(:head)
    visit household_family_studies_url(household_id: households(:home))
    click_on "Schedule a study"
    assert_selector "h1", text: "Schedule a family study"
  end

  test "the form passes assert_accessible" do
    assert_selector "nav[aria-label='Breadcrumb']", text: "Family studies"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Family studies"
    assert_accessible
    capture_screens("schedule-study")
  end

  test "schedule a weekly study and see it listed" do
    date = 7.days.from_now.to_date

    fill_in "What will you study?", with: "Proverbs 3"
    fill_in "Date", with: date
    fill_in "Starts", with: Time.zone.parse("19:00")
    fill_in "Ends", with: Time.zone.parse("19:45")
    select "Weekly on #{date.strftime('%A')}", from: "Repeat"
    click_on "Schedule study"

    assert_text "Your family study is scheduled."
    assert_selector "h1", text: "Family studies"
    assert_selector ".Box-row", text: /Proverbs 3\s*Weekly/
    assert_accessible
  end

  test "changing the date updates the Repeat labels" do
    # The 17th is always a month's third of its weekday and never its last; in November the 24th is always the last.
    third = Date.new(Date.current.year + 1, 11, 17)
    last = third + 7

    fill_in "Date", with: third
    assert_select "Repeat", with_options: [ "Weekly on #{third.strftime('%A')}", "Monthly on the third #{third.strftime('%A')}" ]
    assert_no_selector "option", text: "Monthly on the last"

    fill_in "Date", with: last
    assert_select "Repeat", with_options: [ "Weekly on #{last.strftime('%A')}", "Monthly on the fourth #{last.strftime('%A')}", "Monthly on the last #{last.strftime('%A')}" ]
    assert_accessible
  end

  test "a Repeat choice made while the date reloads is kept" do
    date = Date.current + 1
    # Hold the Repeat frame's request until released, so the choice lands while it's in flight.
    execute_script(<<~JS)
      const fetch = window.fetch
      window.fetch = (url, options) => String(url).includes("family_study_scheduling")
        ? new Promise(resolve => { window.releaseRepeatFrame = () => resolve(fetch(url, options)) })
        : fetch(url, options)
    JS

    fill_in "Date", with: date
    assert_selector "turbo-frame#family_study_scheduling_repeat[busy]"
    select "Daily", from: "Repeat"
    execute_script("window.releaseRepeatFrame()")

    assert_select "Repeat", with_options: [ "Weekly on #{date.strftime('%A')}" ], selected: "Daily"
  end
end
