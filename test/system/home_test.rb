require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase
  setup do
    @home = households(:home)
    @home.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    @home.enable_meeting_helper(by: users(:head))
    @home.enable_meeting_prep(by: users(:head))
  end

  test "a child with Get ready on sees its card on a day that isn't a meeting day, and its sidebar item" do
    travel_to Time.utc(2026, 11, 10, 16) # Tuesday of the week of 9 November, which has cards (prep_week_cards.yml)
    sign_in identities(:eli)
    visit household_root_url(household_id: @home)

    within(".get-ready-card") do
      assert_selector "h2", text: "Get ready"
      assert_text "Read this week's cards with Mom or Dad."
    end
    assert_no_text "Today's meeting ·"
    assert_link "Get ready", href: household_meeting_preps_path(household_id: @home)
    within("nav[aria-label='Main']") { assert_link "Get ready" }
    assert_accessible
    capture_screens("home-get-ready")
  end

  test "on a meeting day, Get ready is the second button on the Today's meeting card" do
    travel_to Time.utc(2026, 11, 12, 16) # Thursday of the same week, the midweek meeting at 7pm
    sign_in identities(:eli)
    visit household_root_url(household_id: @home)

    within(".todays-meeting-card") do
      assert_button "Start"
      assert_link "Get ready", href: household_meeting_preps_path(household_id: @home)
    end
    assert_no_selector ".get-ready-card"
    assert_accessible
    capture_screens("home-meeting-get-ready")
  end

  test "neither with no cards this week" do
    travel_to Time.utc(2026, 11, 17, 16) # Tuesday of the week of 16 November, which has none
    sign_in identities(:eli)
    visit household_root_url(household_id: @home)

    assert_selector "h1", text: "Home"
    assert_no_selector ".get-ready-card"
    assert_no_link "Get ready"

    travel_to Time.utc(2026, 11, 19, 16) # its Thursday, a meeting day
    visit household_root_url(household_id: @home)

    assert_selector ".todays-meeting-card"
    assert_no_link "Get ready"
  end

  test "neither for a head" do
    travel_to Time.utc(2026, 11, 12, 16)
    sign_in identities(:head)
    visit household_root_url(household_id: @home)

    assert_selector ".todays-meeting-card"
    assert_no_link "Get ready"
  end
end
