require "application_system_test_case"

class ListeningGamePlayTest < ApplicationSystemTestCase
  TABLET = { tablet: [ 1180, 820 ] }

  setup do
    households(:home).enable_meeting_helper(by: users(:head))
    # The home household's game is for this week (listening_games.yml): a first talk round with Jeremiah to find.
    @note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    listening_round("talk", 2, answer: "<b>Ruth</b>", others: [ "A rainbow", "A lion", "A boat" ], kind: "thing")
  end

  test "a child plays a step through: Listen again, You heard it!, Next round, then Next part" do
    sign_in identities(:eli)
    visit household_meeting_note_step_url(household_id: households(:home), meeting_note_id: @note, id: "talk")

    assert_text "Treasures From God's Word · Round 1 of 2"
    assert_selector "h1", text: "Tap it when you hear it."
    assert_selector "button[name=card]", count: 4
    assert_link "Next part"
    assert_accessible
    capture_screens("game-round", viewports: TABLET)

    click_button "Noah"

    assert_selector "button[name=card]", text: "Listen again", count: 1
    assert_selector "button[name=card]", text: /Noah\s+Listen again/
    assert_selector "h1", text: "Tap it when you hear it."
    assert_accessible
    capture_screens("game-again", viewports: TABLET)

    click_button "Jeremiah"

    assert_selector "h1", text: "You heard it!"
    assert_selector "button[aria-pressed=true]", text: /Jeremiah\s+You heard it!/
    assert_no_text "Listen again"
    assert_accessible
    capture_screens("game-found", viewports: TABLET)

    click_on "Next round"

    assert_text "Round 2 of 2"
    assert_selector "button[name=card]", text: "<b>Ruth</b>"
    assert_no_selector "button[name=card] b"
    click_button "<b>Ruth</b>"

    assert_selector "h1", text: "You heard it!"
    assert_selector "button[aria-pressed=true]", text: "<b>Ruth</b>"
    assert_no_selector "button[name=card] b"
    assert_no_link "Next round"
    click_on "Next part"

    assert_selector "h1", text: "Listen for something kind Jehovah did."
    assert_equal 2, @note.reload.found_count
  end

  test "she finishes with finds and an answer, shows her family, and a head reads them, even after a round changed" do
    @note.write_answer(paragraph: 7, body: "Jehovah helps us when we are sad.")
    @note.mark("congregation_bible_study")
    sign_in identities(:eli)
    visit household_meeting_note_step_url(household_id: households(:home), meeting_note_id: @note, id: "talk")
    click_button "Jeremiah"
    click_on "Next round"
    click_button "<b>Ruth</b>"
    assert_selector "h1", text: "You heard it!"

    visit household_meeting_note_summary_url(household_id: households(:home), meeting_note_id: @note)

    assert_selector "h1", text: "You found 2 things today!"
    assert_selector "li#summary-talk", text: "Found 2"
    assert_selector "li#summary-congregation_bible_study", text: "Gave my answer"
    assert_accessible
    capture_screens("game-done", viewports: TABLET)
    click_on "Show my family"
    assert_selector "[role=status]", text: "Your family can see it now"

    # A head changes the round after she found it; her find keeps its own label (Trap 5).
    listening_game_cards(:home_talk_jeremiah).update!(label: "Isaiah")
    sign_out :identity
    sign_in identities(:head)
    visit household_shared_meeting_notes_url(household_id: households(:home))
    within("main .Box-row", text: "Eli Child") { click_on "Life and Ministry" }

    assert_selector "li", text: "You found Jeremiah. What do you remember about it?"
    assert_selector "li", text: "You found <b>Ruth</b>. What do you remember about it?"
    assert_selector "li", text: "Tell me about your answer for paragraph 7."
    within("#helper-note-answer") do
      assert_selector "h3", text: "Eli's answer for Bible study"
      assert_text "Paragraph 7"
      assert_text "Jehovah helps us when we are sad."
      assert_text "Gave it at the meeting"
    end
    within("#helper-note-finds") do
      assert_selector "h3", text: "Listening game · found 2"
      assert_selector ".Box-row", text: /Treasures\s+Jeremiah, <b>Ruth<\/b>/
    end
    assert_no_text "Isaiah"
    assert_no_selector "main b"
    assert_accessible
    capture_screens("game-shared")
  end

  test "she writes her answer the evening before, then taps I gave my answer! at the meeting" do
    travel_to Time.utc(2026, 11, 11, 18) # Wednesday evening, the day before the midweek meeting
    households(:home).change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    listening_round("congregation_bible_study", 1, answer: "Elijah", others: [ "Moses", "Jericho", "A jar of oil" ])
    sign_in identities(:eli)
    visit household_todays_meeting_url(household_id: households(:home))
    assert_selector "h1", text: "Sing along with everyone."

    visit household_meeting_note_step_url(household_id: households(:home), meeting_note_id: @note, id: "congregation_bible_study")
    assert_text "Congregation Bible Study · Round 1 of 1"
    assert_accessible
    capture_screens("game-study-write-link", viewports: TABLET)
    click_on "Write my answer"

    assert_selector "h1", text: "My answer for Bible study"
    fill_in "Paragraph", with: "7"
    fill_in "What I'll say", with: "Jehovah helps us when we are sad."
    assert_accessible
    capture_screens("game-write-answer", viewports: TABLET)
    click_on "Save my answer"

    assert_text "My answer · paragraph 7"
    assert_text "Jehovah helps us when we are sad."
    assert_link "Change my answer"
    assert_selector "button[name=card]", count: 4

    travel_to Time.utc(2026, 11, 12, 19, 40) # at the meeting
    visit household_todays_meeting_url(household_id: households(:home))
    visit household_meeting_note_step_url(household_id: households(:home), meeting_note_id: @note, id: "congregation_bible_study")

    assert_selector "h1", text: "Tap it when you hear it."
    assert_text "My answer · paragraph 7"
    assert_accessible
    capture_screens("game-study", viewports: TABLET)
    click_button "I gave my answer!"

    assert_selector "button[aria-pressed=true]", text: "Gave my answer"
    assert @note.reload.marked?("congregation_bible_study")
  end

  test "with no game rounds, her answer card still shows on today's step" do
    note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    note.write_answer(paragraph: 3, body: "<b>Noah</b> listened to Jehovah.")
    sign_in identities(:eli)
    visit household_meeting_note_step_url(household_id: households(:home), meeting_note_id: note, id: "congregation_bible_study")

    assert_selector "h1", text: "Look at the pictures. Which one do you like?"
    assert_text "My answer · paragraph 3"
    assert_text "<b>Noah</b> listened to Jehovah."
    assert_no_selector "main b"
    assert_link "Change my answer"
    assert_link "Draw it"
    assert_accessible
    capture_screens("game-study-no-rounds", viewports: TABLET)
    click_button "I gave my answer!"

    assert_selector "button[aria-pressed=true]", text: "Gave my answer"
    assert note.reload.marked?("congregation_bible_study")
  end

  test "without an answer, today's step offers Write my answer and keeps I watched!" do
    note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    sign_in identities(:eli)
    visit household_meeting_note_step_url(household_id: households(:home), meeting_note_id: note, id: "congregation_bible_study")

    assert_link "Write my answer"
    assert_no_text "My answer ·"
    assert_button "I watched!"
    assert_accessible
    capture_screens("game-study-no-answer", viewports: TABLET)
  end
end
