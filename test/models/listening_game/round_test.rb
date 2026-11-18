require "test_helper"

class ListeningGame::RoundTest < ActiveSupport::TestCase
  setup { @round = listening_game_rounds(:home_talk_first) }

  test "a round has its cards in grid order and its answer" do
    assert_equal %w[ Noah Jeremiah Moses Daniel ], @round.cards.map(&:label)
    assert_equal listening_game_cards(:home_talk_jeremiah), @round.answer
  end

  test "database: two rounds at one position in a step" do
    assert_raises(ActiveRecord::RecordNotUnique) { ListeningGame::Round.insert!(row(position: 1)) }
  end

  test "database: the same position in another step is fine" do
    assert ListeningGame::Round.insert!(row(position: 1, step: "bible_reading"))
  end

  test "database: a step that isn't one of the four game steps" do
    assert_raises(ActiveRecord::CheckViolation) { @round.update_column(:step, "field_ministry") }
  end

  test "database: a round needs a position" do
    assert_raises(ActiveRecord::NotNullViolation) { ListeningGame::Round.insert!(row(position: nil)) }
  end

  private
    def row(**changes)
      { listening_game_id: @round.listening_game_id, step: "talk", position: 2 }.merge(changes)
    end
end
