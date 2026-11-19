require "test_helper"

class MeetingNotes::Steps::RoundsControllerTest < ActionDispatch::IntegrationTest
  setup do
    households(:home).enable_meeting_helper(by: users(:head))
    # The home household's game is for this week (listening_games.yml), with one talk round.
    @note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    @second = listening_round("talk", 2, answer: "Ruth", others: %w[ Esther Joseph David ])
  end

  test "a step with rounds redirects to the first round she hasn't found" do
    sign_in identities(:eli)

    get step_path("talk")

    assert_redirected_to round_path("talk", 1)

    @note.find_card(listening_game_cards(:home_talk_jeremiah))
    get step_path("talk")

    assert_redirected_to round_path("talk", 2)
  end

  test "once she's found them all, the step redirects to the last round" do
    @note.find_card(listening_game_cards(:home_talk_jeremiah))
    @note.find_card(@second.answer)
    sign_in identities(:eli)

    get step_path("talk")

    assert_redirected_to round_path("talk", 2)
  end

  test "a step with no rounds shows today's page" do
    sign_in identities(:eli)

    get step_path("spiritual_gems")

    assert_response :success
    assert_select "main h1", "Listen for something kind Jehovah did."
    assert_select "main ##{dom_id(@note, :mark)} button", text: "I heard it!"
  end

  test "another week's note has no rounds" do
    note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 16))
    sign_in identities(:eli)

    get household_meeting_note_step_path(household_id: households(:home), meeting_note_id: note, id: "talk")

    assert_response :success
    assert_select "main h1", "Listen for someone from the Bible."
  end

  test "a round shows its step, Round N of M, the heading, four card buttons and the footer" do
    sign_in identities(:eli)

    get round_path("talk", 1)

    assert_response :success
    assert_select "body[data-color-mode=dark]"
    assert_select "main", text: /Treasures From God's Word · Round 1 of 2/
    assert_select "main h1", "Tap it when you hear it."
    assert_select "main form[action='#{find_path("talk", 1)}'] button[name=card]", count: 4
    assert_select "main button[name=card][value='#{listening_game_cards(:home_talk_jeremiah).id}']", text: /Jeremiah/
    assert_select "main button[aria-pressed=true]", count: 0
    assert_select "main .meeting-helper__icon svg[aria-hidden=true]", count: 4
    assert_select "nav a[href='#{step_path("opening_song")}']", "Back"
    assert_select "nav a[href='#{edit_household_meeting_note_step_drawing_path(household_id: households(:home), meeting_note_id: @note, step_id: "talk")}']", "Draw it"
    assert_select "nav a[href='#{step_path("spiritual_gems")}']", "Next part"
  end

  test "a found round says You heard it!, presses the answer and offers Next round" do
    @note.find_card(listening_game_cards(:home_talk_jeremiah))
    sign_in identities(:eli)

    get round_path("talk", 1)

    assert_select "main h1", "You heard it!"
    assert_select "main button[aria-pressed=true][value='#{listening_game_cards(:home_talk_jeremiah).id}']", text: /Jeremiah\s+You heard it!/
    assert_select "main button[aria-pressed=true]", count: 1
    assert_select "nav a[href='#{round_path("talk", 2)}']", "Next round"
  end

  test "Back on a later round goes to the round before, and the last round's Next is Next part" do
    @note.find_card(@second.answer)
    sign_in identities(:eli)

    get round_path("talk", 2)

    assert_select "main", text: /Round 2 of 2/
    assert_select "nav a[href='#{round_path("talk", 1)}']", "Back"
    assert_select "nav a[href='#{step_path("spiritual_gems")}']", "Next part"
  end

  test "a round that isn't there is 404" do
    sign_in identities(:eli)

    get round_path("talk", 3)

    assert_response :not_found
  end

  test "an adult is 404" do
    note = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    sign_in identities(:spouse)

    get household_meeting_note_step_round_path(household_id: households(:home), meeting_note_id: note, step_id: "talk", id: 1)

    assert_response :not_found
  end

  test "another child's note is 404" do
    note = users(:sofia).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    sign_in identities(:eli)

    get household_meeting_note_step_round_path(household_id: households(:home), meeting_note_id: note, step_id: "talk", id: 1)

    assert_response :not_found
  end

  test "the helper off is 404" do
    households(:home).disable_meeting_helper
    sign_in identities(:eli)

    get round_path("talk", 1)

    assert_response :not_found
  end

  private
    def step_path(key)
      household_meeting_note_step_path(household_id: households(:home), meeting_note_id: @note, id: key)
    end

    def round_path(key, position)
      household_meeting_note_step_round_path(household_id: households(:home), meeting_note_id: @note, step_id: key, id: position)
    end

    def find_path(key, position)
      household_meeting_note_step_round_find_path(household_id: households(:home), meeting_note_id: @note, step_id: key, round_id: position)
    end
end
