require "test_helper"

class ListeningGameTest < ActiveSupport::TestCase
  setup { @game = listening_games(:home_nov_9) }

  test "a game has its rounds in step order, then position, and its sources in order" do
    gems = @game.rounds.create!(step: "spiritual_gems", position: 1)
    second = @game.rounds.create!(step: "talk", position: 2)

    assert_equal [ listening_game_rounds(:home_talk_first), second, gems ], @game.rounds.to_a
    assert_equal [ listening_game_sources(:home_program) ], @game.sources.to_a
  end

  test "deleting the household deletes its games, rounds, cards and sources" do
    rows = [ @game, listening_game_rounds(:home_talk_first), listening_game_cards(:home_talk_jeremiah), listening_game_sources(:home_program) ]

    households(:home).destroy!

    rows.each { assert_not it.class.exists?(it.id) }
  end

  test "deleting its chat keeps the game" do
    chat = Chat.create!(user: users(:head), household: households(:home), purpose: "listening_game")
    @game.update!(chat: chat)

    chat.destroy!

    assert_nil @game.reload.chat_id
  end

  test "database: a second game for the same household and week" do
    assert_raises(ActiveRecord::RecordNotUnique) { ListeningGame.insert!({ household_id: @game.household_id, week_of: @game.week_of }) }
  end

  test "database: a game needs a week" do
    assert_raises(ActiveRecord::NotNullViolation) { ListeningGame.insert!({ household_id: @game.household_id, week_of: nil }) }
  end

  test "database: two sources at one position" do
    assert_raises(ActiveRecord::RecordNotUnique) { ListeningGame::Source.insert!(source(position: 1)) }
  end

  test "database: a source that isn't https" do
    assert_raises(ActiveRecord::CheckViolation) { ListeningGame::Source.insert!(source(url: "http://wol.jw.org/en/")) }
  end

  test "database: a source needs a title" do
    assert_raises(ActiveRecord::NotNullViolation) { ListeningGame::Source.insert!(source(title: nil)) }
  end

  private
    def source(**changes)
      { listening_game_id: @game.id, position: 2, title: "Congregation Bible Study", url: "https://wol.jw.org/en/wol/d/r1/lp-e/1" }.merge(changes)
    end
end
