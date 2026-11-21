require "application_system_test_case"

# The parent's Get ready page and Change a card (docs/design/meeting-prep.md, On a parent's phone; frames
# phone-prep-check.png and phone-prep-change.png).
class MeetingPrepParentTest < ApplicationSystemTestCase
  setup do
    # Thursday of the week of 9 November, a midweek meeting day, whose talk and Bible Reading cards are in
    # prep_week_cards.yml. The Watchtower card and the pages the AI used are added here.
    travel_to Time.utc(2026, 11, 12, 12)
    @home = households(:home)
    @home.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    @home.enable_meeting_helper(by: users(:head))
    @home.enable_meeting_prep(by: users(:head))
    week = prep_weeks(:home_nov_9)
    week.cards.create!(meeting: "weekend", step: "watchtower_study", about: "Jehovah listens when we pray.", quality: "loving",
                       quality_line: "He hears every prayer.", i_can: "Say a prayer before bed.")
    week.sources.create!(position: 1, title: "Life and Ministry Meeting Workbook, November 9-15", url: "https://wol.jw.org/en/wol/d/r1/lp-e/202026401")
    week.sources.create!(position: 2, title: "The Watchtower, study article for November 15", url: "https://wol.jw.org/en/wol/d/r1/lp-e/2026601")
  end

  test "a head goes from Home to this week's cards, changes the talk's I can…, and the child's card shows it" do
    sign_in identities(:head)
    visit household_root_url(household_id: @home)

    within(".todays-meeting-card") { click_on "This week's Get ready cards" }

    assert_selector "h1", text: "This week's Get ready cards"
    assert_text "Week of November 9–15, 2026"
    assert_text "AI wrote these from this week's program. Eli can see them now. Change anything that isn't right."
    assert_link "Life and Ministry Meeting Workbook, November 9-15"
    assert_link "The Watchtower, study article for November 15"
    within("#meeting-prep-midweek") do
      assert_text "2 cards"
      assert_text "Bible Reading · Lamentations 1–2"
      assert_text "Jehovah cares · I can: Tell Jehovah when I feel sad."
    end
    within("#meeting-prep-weekend") { assert_text "Jehovah is loving · I can: Say a prayer before bed." }
    assert_accessible
    capture_screens("prep-check")

    within("#prep_week_card_#{prep_week_cards(:home_nov_9_talk).id}") { click_on "Change" }

    assert_selector "dialog[open] h1", text: "Treasures From God's Word"
    assert_field "What it's about", with: "Jeremiah felt very sad. But he remembered that Jehovah never stops caring."
    assert_select "Jehovah is…", selected: "Jehovah cares"
    wait_for_dialog
    assert_accessible
    capture_screens("prep-change")

    fill_in "I can…", with: "Draw Jehovah a <b>thank-you</b> picture."
    click_on "Save"

    assert_no_selector "dialog[open]"
    assert_text "Card saved."
    within("#prep_week_card_#{prep_week_cards(:home_nov_9_talk).id}") do
      assert_text "Jehovah cares · I can: Draw Jehovah a <b>thank-you</b> picture."
    end
    assert_accessible

    sign_out :identity
    sign_in identities(:eli)
    visit household_meeting_prep_card_url(household_id: @home, meeting_prep_meeting: "midweek", id: "talk")

    within(".meeting-prep__i-can") { assert_text "Draw Jehovah a <b>thank-you</b> picture." }
  end

  test "an adult with no cards this week: Cards aren't ready yet" do
    travel_to Time.utc(2026, 11, 17, 12)
    users(:spouse).accept_ai_terms(understood: true)
    sign_in identities(:spouse)

    visit household_meeting_preps_url(household_id: @home)

    assert_selector "h1", text: "This week's Get ready cards"
    assert_selector "h2", text: "Cards aren't ready yet"
    assert_no_link "Change"
    assert_accessible
    capture_screens("prep-check-not-ready")
  end
end
