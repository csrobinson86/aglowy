require "test_helper"

class ListeningGame::Round::ChangeTest < ActiveSupport::TestCase
  test "saving over a round another parent has just changed writes every label, so no label is on two cards" do
    stale = ListeningGame::Round.find(listening_game_rounds(:home_talk_first).id)
    change = ListeningGame::Round::Change.new(stale, other_label_1: "Isaiah")
    ListeningGame::Round::Change.new(ListeningGame::Round.find(stale.id), answer_label: "Isaiah").save(by: users(:spouse))

    assert change.save(by: users(:head))

    assert_equal %w[ Isaiah Jeremiah Moses Daniel ], listening_game_rounds(:home_talk_first).cards.reload.map(&:label)
    assert_equal users(:head), listening_game_rounds(:home_talk_first).reload.changed_by
  end
end
