require "application_system_test_case"

class MeetingPrepTest < ApplicationSystemTestCase
  TABLET = { tablet: [ 1180, 820 ] }

  setup do
    # Tuesday of the week of 9 November: no meeting today, and the week's talk and Bible Reading cards are in
    # prep_week_cards.yml. The other two midweek cards, and the frame's four-sentence story, are added here.
    travel_to Time.utc(2026, 11, 10, 16)
    @home = households(:home)
    @home.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    @home.enable_meeting_helper(by: users(:head))
    @home.enable_meeting_prep(by: users(:head))
    week = prep_weeks(:home_nov_9)
    prep_week_cards(:home_nov_9_bible_reading).update!(story: [
      "Jerusalem was the city where Jehovah’s people lived.", "The people stopped listening to Jehovah.",
      "An army came and broke the city.", "Jeremiah cried and asked Jehovah to help his people."
    ])
    week.cards.create!(meeting: "midweek", step: "living", about: "<b>Being kind</b> to people who are sad.", quality: "kind",
                       quality_line: "Jehovah comforts people who are sad.", i_can: "Give someone a hug.")
    week.cards.create!(meeting: "midweek", step: "congregation_bible_study", about: "Jesus loved little children.", quality: "loving",
                       quality_line: "Jesus showed us how Jehovah loves.", i_can: "Smile at the people at the meeting.")
  end

  test "from Home to Get ready, Start, and through every midweek card to All done" do
    sign_in identities(:eli)
    visit household_root_url(household_id: @home)

    within(".get-ready-card") { click_on "Get ready" }

    assert_selector "h1", text: "Get ready for the meetings"
    assert_text "Ask Mom or Dad to read the cards with you."
    assert_text "Week of November 9"
    within(".meeting-prep__tile", text: "Midweek meeting") { assert_text "4 cards" }
    within(".meeting-prep__tile", text: "Weekend meeting") { assert_text "Cards aren't ready yet" }
    assert_accessible
    capture_screens("prep-week", viewports: TABLET)
    within(".meeting-prep__tile", text: "Midweek meeting") { click_on "Start" }

    assert_selector "h1", text: "Jeremiah felt very sad. But he remembered that Jehovah never stops caring."
    assert_text "Treasures From God's Word · Card 1 of 4"
    assert_text "Jehovah cares"
    assert_text "I can…"
    assert_accessible
    capture_screens("prep-card", viewports: TABLET)
    click_on "Next card"

    assert_selector "h1", text: "A sad song about Jerusalem."
    assert_text "Bible Reading · Card 2 of 4"
    within(".meeting-prep__story") do
      assert_selector "h2", text: "The story · Lamentations 1–2"
      assert_selector "li", count: 4
      assert_selector "li", text: "Jeremiah cried and asked Jehovah to help his people."
    end
    assert_text "Jehovah is fair"
    assert_accessible
    capture_screens("prep-reading", viewports: TABLET)
    click_on "Next card"

    # Card text is untrusted: a tag in it shows as text (Trap 4).
    assert_selector "h1", text: "<b>Being kind</b> to people who are sad."
    assert_no_selector "h1 b"
    assert_text "Living as Christians · Card 3 of 4"
    click_on "Next card"

    assert_selector "h1", text: "Jesus loved little children."
    assert_text "Congregation Bible Study · Card 4 of 4"
    assert_no_link "Next card"
    click_on "All done"

    assert_selector "h1", text: "Get ready for the meetings"
  end
end
