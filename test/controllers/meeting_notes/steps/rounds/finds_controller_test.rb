require "test_helper"

class MeetingNotes::Steps::Rounds::FindsControllerTest < ActionDispatch::IntegrationTest
  setup do
    households(:home).enable_meeting_helper(by: users(:head))
    # The home household's game is for this week (listening_games.yml), with one talk round.
    @note = users(:eli).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    @answer = listening_game_cards(:home_talk_jeremiah)
  end

  test "the right card makes one find, and the Turbo Stream shows the found state" do
    sign_in identities(:eli)

    assert_difference -> { @note.finds.count }, 1 do
      post find_path, params: { card: @answer.id }, as: :turbo_stream
    end

    assert_response :success
    assert_select "turbo-stream[action=replace][target=#{dom_id(@note, :round)}]" do
      assert_select "template h1", "You heard it!"
      assert_select "template button[aria-pressed=true][autofocus][value='#{@answer.id}']", text: /Jeremiah\s+You heard it!/
    end
    assert_equal [ "Jeremiah" ], @note.finds_for("talk").map(&:label)
  end

  test "tapping the right card twice still makes one find" do
    sign_in identities(:eli)

    assert_difference -> { @note.finds.count }, 1 do
      2.times { post find_path, params: { card: @answer.id }, as: :turbo_stream }
    end
    assert_response :success
  end

  test "a wrong card makes no find and says Listen again on it" do
    noah = listening_game_cards(:home_talk_noah)
    sign_in identities(:eli)

    assert_no_difference -> { MeetingNote::Find.count } do
      post find_path, params: { card: noah.id }, as: :turbo_stream
    end

    assert_response :success
    assert_select "turbo-stream[action=replace][target=#{dom_id(@note, :round)}]" do
      assert_select "template h1", "Tap it when you hear it."
      assert_select "template button[autofocus][value='#{noah.id}']", text: /Noah\s+Listen again/
      assert_select "template button", text: /Listen again/, count: 1
      assert_select "template button[aria-pressed=true]", count: 0
    end
  end

  test "without Turbo, a tap goes back to the round" do
    sign_in identities(:eli)

    post find_path, params: { card: @answer.id }

    assert_redirected_to household_meeting_note_step_round_path(household_id: households(:home), meeting_note_id: @note, step_id: "talk", id: 1)
  end

  test "a card from another round is 404" do
    other = listening_round("talk", 2, answer: "Ruth", others: %w[ Esther Joseph David ])
    sign_in identities(:eli)

    post find_path, params: { card: other.answer.id }, as: :turbo_stream

    assert_response :not_found
    assert_empty @note.finds
  end

  test "a list of cards is a bad request" do
    sign_in identities(:eli)

    post find_path, params: { card: [ @answer.id ] }, as: :turbo_stream

    assert_response :bad_request
    assert_empty @note.finds
  end

  test "an adult is 404" do
    note = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    sign_in identities(:spouse)

    post find_path(note), params: { card: @answer.id }, as: :turbo_stream

    assert_response :not_found
    assert_empty note.finds
  end

  test "another child's note is 404" do
    note = users(:sofia).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    sign_in identities(:eli)

    post find_path(note), params: { card: @answer.id }, as: :turbo_stream

    assert_response :not_found
    assert_empty note.finds
  end

  test "the helper off is 404" do
    households(:home).disable_meeting_helper
    sign_in identities(:eli)

    post find_path, params: { card: @answer.id }, as: :turbo_stream

    assert_response :not_found
    assert_empty @note.finds
  end

  private
    def find_path(note = @note)
      household_meeting_note_step_round_find_path(household_id: households(:home), meeting_note_id: note, step_id: "talk", round_id: 1)
    end
end
