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

  test "Get my comment ready on the Bible Study card, write it, and back on the card with it; Change" do
    sign_in identities(:eli)
    visit card_url("midweek", "congregation_bible_study")

    within(".meeting-prep__comment") do
      assert_selector "h2", text: "My comment"
      assert_text "Pick a paragraph with your family. Then say it your own way."
    end
    assert_accessible
    capture_screens("prep-study-comment", viewports: TABLET)
    click_on "Get my comment ready"

    assert_selector "h1", text: "My answer for Bible study"
    fill_in "Paragraph", with: "7"
    fill_in "What I'll say", with: "Jehovah helps us when we are sad."
    click_on "Save my answer"

    assert_selector "h1", text: "Jesus loved little children."
    within(".meeting-prep__comment") do
      assert_selector "h2", text: "My comment · paragraph 7"
      assert_text "Jehovah helps us when we are sad."
    end
    assert_accessible
    click_on "Change"

    assert_field "Paragraph", with: "7"
    click_on "Back"

    assert_selector "h1", text: "Jesus loved little children."
    click_on "Change"
    fill_in "What I'll say", with: "Jesus was kind to children."
    click_on "Save my answer"

    within(".meeting-prep__comment") { assert_text "Jesus was kind to children." }
    click_on "All done"

    within(".meeting-prep__tile", text: "Midweek meeting") { assert_text "My comment is ready" }
  end

  test "Draw it! on the Bible Reading card, All done back on the card, and the same drawing in the helper" do
    sign_in identities(:eli)
    visit card_url("midweek", "bible_reading")
    click_on "Draw it!"

    assert_selector "h1", text: "Draw something from the reading."
    click_on "All done" # nothing drawn: back to the card, saving nothing

    assert_selector "h1", text: "A sad song about Jerusalem."
    click_on "Draw it!"
    canvas = find("canvas[aria-label='Drawing space. Draw with your finger.']")
    page.driver.browser.action.move_to(canvas.native, -200, 0).pointer_down.move_by(400, 0).pointer_up.perform
    click_on "All done"

    assert_selector "h1", text: "A sad song about Jerusalem."
    note = users(:eli).meeting_notes.find_by!(kind: "midweek", week_of: Date.new(2026, 11, 9))
    assert note.drawn?("bible_reading")
    visit household_meeting_note_step_url(household_id: @home, meeting_note_id: note, id: "bible_reading")

    assert_link "My drawing"
  end

  test "her Watchtower comment from Get ready, I gave my answer! at the weekend meeting, and a parent reads it shared" do
    prep_weeks(:home_nov_9).cards.create!(meeting: "weekend", step: "watchtower_study", about: "Jehovah gives us friends.", quality: "loving",
                                          quality_line: "He gives us a family at the meetings.", i_can: "Say hello to someone new.")
    sign_in identities(:eli)
    visit card_url("weekend", "watchtower_study")
    click_on "Get my comment ready"

    assert_selector "h1", text: "My comment for the Watchtower"
    fill_in "Paragraph", with: "7"
    fill_in "What I'll say", with: "Jehovah gives us friends at the Kingdom Hall."
    click_on "Save my answer"

    within(".meeting-prep__comment") do
      assert_selector "h2", text: "My comment · paragraph 7"
      assert_text "Jehovah gives us friends at the Kingdom Hall."
    end
    assert_accessible
    capture_screens("prep-watchtower", viewports: TABLET)

    note = users(:eli).meeting_notes.find_by!(kind: "weekend", week_of: Date.new(2026, 11, 9))
    visit household_meeting_note_step_url(household_id: @home, meeting_note_id: note, id: "watchtower_study")

    within(".meeting-helper__answer") do
      assert_text "My answer · paragraph 7"
      assert_text "Jehovah gives us friends at the Kingdom Hall."
    end
    assert_accessible
    capture_screens("prep-watchtower-step", viewports: TABLET)
    click_on "I gave my answer!"

    assert_selector "button[aria-pressed=true]", text: "Gave my answer"
    note.share_with(@home)
    sign_in identities(:head)
    visit household_meeting_note_url(household_id: @home, id: note)

    assert_text "Tell me about your answer for paragraph 7."
    within("#helper-note-answer") { assert_text "Eli's comment for the Watchtower" }
    assert_accessible
  end

  private
    def card_url(meeting, step)
      household_meeting_prep_card_url(household_id: @home, meeting_prep_meeting: meeting, id: step)
    end
end
