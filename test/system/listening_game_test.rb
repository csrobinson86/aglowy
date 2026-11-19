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
end
