require "test_helper"

class ListeningGames::RoundsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 11, 11, 12)
    households(:home).enable_meeting_helper(by: users(:head))
    @round = listening_game_rounds(:home_talk_first)
    listening_round("talk", 2, answer: "Tears", others: [ "A rainbow", "A lion", "A boat" ], kind: "feeling")
    sign_in identities(:head)
  end

  test "edit is a dialog with the answer's label and kind, and the three other labels" do
    get edit_round_path(@round)

    assert_response :success
    assert_select "turbo-frame#listening_game_round_dialog dialog[open]" do
      assert_select "h1", "Treasures · round 1 of 2"
      assert_select "form[action=?]", round_path(@round) do
        assert_select "input[name='listening_game_round_change[answer_label]'][value=Jeremiah][maxlength='40']"
        assert_select "label", /\AHeard in the talk/
        assert_select "select[name='listening_game_round_change[answer_kind]'] option[selected][value=person]"
        assert_select "input[name='listening_game_round_change[other_label_1]'][value=Noah]"
        assert_select "input[name='listening_game_round_change[other_label_2]'][value=Moses]"
        assert_select "input[name='listening_game_round_change[other_label_3]'][value=Daniel]"
        assert_select "button[type=submit]", "Save"
      end
    end
  end

  test "change a round: the labels and kind change, changed_by is set, and the cards keep their positions" do
    patch round_path(@round), as: :turbo_stream, params: { listening_game_round_change: {
      answer_label: "  Isaiah ", answer_kind: "book", other_label_1: "Ruth", other_label_2: "Esther", other_label_3: "Jonah" } }

    assert_response :success
    assert_equal [ [ 1, "Ruth", "person", false ], [ 2, "Isaiah", "book", true ], [ 3, "Esther", "person", false ], [ 4, "Jonah", "person", false ] ],
                 @round.cards.reload.map { [ it.position, it.label, it.kind, it.answer ] }
    assert_equal users(:head), @round.reload.changed_by
    assert_select "turbo-stream[action=update][target=listening_game_round_dialog]"
    assert_select "turbo-stream[action=update][target=listening_game_round_#{@round.id}] template", text: /Isaiah\s+Ruth · Esther · Jonah/
  end

  test "without Turbo, a saved round goes back to the page" do
    patch round_path(@round), params: { listening_game_round_change: {
      answer_label: "Isaiah", answer_kind: "person", other_label_1: "Noah", other_label_2: "Moses", other_label_3: "Daniel" } }

    assert_redirected_to household_listening_game_path(household_id: households(:home))
    assert_equal "Round saved.", flash[:notice]
  end

  test "an adult can change a round" do
    sign_in identities(:spouse)

    patch round_path(@round), params: { listening_game_round_change: {
      answer_label: "Isaiah", answer_kind: "person", other_label_1: "Noah", other_label_2: "Moses", other_label_3: "Daniel" } }

    assert_equal users(:spouse), @round.reload.changed_by
  end

  test "a blank label is refused on its field" do
    patch round_path(@round), params: { listening_game_round_change: {
      answer_label: "Jeremiah", answer_kind: "person", other_label_1: "Noah", other_label_2: " ", other_label_3: "Daniel" } }

    assert_response :unprocessable_content
    assert_select "dialog[open] input[name='listening_game_round_change[other_label_2]'][aria-invalid=true]"
    assert_select "dialog[open]", text: /can't be blank/
    assert_select "dialog[open] input[aria-invalid=true]", count: 1
    assert_equal "Moses", listening_game_cards(:home_talk_moses).reload.label
    assert_nil @round.reload.changed_by
  end

  test "a 41-character label is refused on its field" do
    patch round_path(@round), params: { listening_game_round_change: {
      answer_label: "a" * 41, answer_kind: "person", other_label_1: "Noah", other_label_2: "Moses", other_label_3: "Daniel" } }

    assert_response :unprocessable_content
    assert_select "dialog[open] input[name='listening_game_round_change[answer_label]'][aria-invalid=true]"
    assert_select "dialog[open]", text: /is too long \(maximum is 40 characters\)/
    assert_equal "Jeremiah", listening_game_cards(:home_talk_jeremiah).reload.label
  end

  test "a label on two cards, or a kind that isn't one, is refused on its field" do
    patch round_path(@round), params: { listening_game_round_change: {
      answer_label: "Jeremiah", answer_kind: "animal", other_label_1: "Noah", other_label_2: "noah", other_label_3: "Daniel" } }

    assert_response :unprocessable_content
    assert_select "dialog[open] select[name='listening_game_round_change[answer_kind]'][aria-invalid=true]"
    assert_select "dialog[open] input[name='listening_game_round_change[other_label_2]'][aria-invalid=true]"
    assert_select "dialog[open]", text: /is already on another card/
    assert_equal "Moses", listening_game_cards(:home_talk_moses).reload.label
  end

  test "a round from another household's game is a 404" do
    game = households(:other).listening_games.create!(week_of: Date.new(2026, 11, 9))
    other = listening_round("talk", 1, answer: "Ruth", others: %w[ Esther Joseph David ], game:)

    get edit_round_path(other)
    assert_response :not_found

    sign_in identities(:head) # A 404 from an exception sets no session cookie, so the test sign-in doesn't last.
    patch round_path(other), params: { listening_game_round_change: { answer_label: "Isaiah" } }
    assert_response :not_found
    assert_equal "Ruth", other.answer.reload.label
  end

  test "a child, or the helper off, is a 404" do
    sign_in identities(:eli)
    get edit_round_path(@round)
    assert_response :not_found

    households(:home).disable_meeting_helper
    sign_in identities(:head)
    patch round_path(@round), params: { listening_game_round_change: { answer_label: "Isaiah" } }
    assert_response :not_found
    assert_equal "Jeremiah", @round.answer.reload.label
  end

  private
    def edit_round_path(round)
      edit_household_listening_game_round_path(household_id: households(:home), id: round)
    end

    def round_path(round)
      household_listening_game_round_path(household_id: households(:home), id: round)
    end
end
