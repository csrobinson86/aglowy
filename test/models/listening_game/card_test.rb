require "test_helper"

class ListeningGame::CardTest < ActiveSupport::TestCase
  setup { @card = listening_game_cards(:home_talk_noah) }

  test "database: a fifth card" do
    assert_raises(ActiveRecord::CheckViolation) { ListeningGame::Card.insert!(row(position: 5)) }
  end

  test "database: a fifth card in a taken position" do
    assert_raises(ActiveRecord::RecordNotUnique) { ListeningGame::Card.insert!(row(position: 4)) }
  end

  test "database: a card position of 0" do
    assert_raises(ActiveRecord::CheckViolation) { @card.update_column(:position, 0) }
  end

  test "database: an unknown kind" do
    assert_raises(ActiveRecord::CheckViolation) { @card.update_column(:kind, "animal") }
  end

  test "database: a 40-character label is fine, and a 41-character one isn't" do
    @card.update_column(:label, "a" * 40)

    assert_raises(ActiveRecord::CheckViolation) { @card.update_column(:label, "a" * 41) }
  end

  test "database: two answers in one round" do
    assert_raises(ActiveRecord::RecordNotUnique) { @card.update_column(:answer, true) }
  end

  test "database: a card needs a label" do
    assert_raises(ActiveRecord::NotNullViolation) { ListeningGame::Card.insert!(row(label: nil)) }
  end

  private
    def row(**changes)
      { round_id: @card.round_id, position: 5, label: "Elijah", kind: "person" }.merge(changes)
    end
end
