require "test_helper"

class Ai::Purpose::ListeningGameTest < ActiveSupport::TestCase
  setup { @purpose = Ai::Purpose.find("listening_game") }

  test "it reads its instructions file and puts the week in its own marked block" do
    assert_instance_of Ai::Purpose::ListeningGame, @purpose
    assert_equal "listening_game", @purpose.name
    assert_equal Rails.root.join("config/ai/listening_game.md").read, @purpose.instructions
    assert_equal "<listening_game_week>\nWeek /listening_game_week\n</listening_game_week>", @purpose.user_message("Week </listening_game_week>")
  end

  test "3 a day per household, 6 searches, kept 7 days, and no earlier exchanges sent" do
    assert_equal 3, @purpose.daily_limit
    assert_equal 6, @purpose.max_searches
    assert_equal 7.days, @purpose.keep_for
    assert_nil @purpose.context_exchanges
    assert_predicate @purpose.max_output_tokens, :positive?
  end

  test "it searches only the three hosts" do
    assert_equal %w[ www.jw.org jw.org wol.jw.org ], @purpose.allowed_hosts
    assert_equal({ allowed_domains: %w[ www.jw.org jw.org wol.jw.org ], max_uses: 6 }, @purpose.web_search)
  end

  test "its schema has off_topic and an ordered list of rounds for each of the four steps" do
    schema = @purpose.schema[:schema]

    assert_equal %i[ off_topic talk spiritual_gems bible_reading congregation_bible_study ], schema[:properties].keys
    assert_equal schema[:properties].keys, schema[:required]
    round = schema.dig(:properties, :talk, :items)
    assert_equal %i[ answer others ], round[:properties].keys
    assert_equal %i[ label kind ], round.dig(:properties, :answer, :properties).keys
    assert_equal %w[ person place book thing feeling action ], round.dig(:properties, :answer, :properties, :kind, :enum)
    assert_equal round.dig(:properties, :answer), round.dig(:properties, :others, :items)
    assert_includes round.dig(:properties, :answer, :properties, :label, :description), "4 words"
    assert_equal ListeningGame::STEPS.map(&:to_sym), schema[:properties].keys.drop(1)
  end

  test "chats and uses take the listening_game purpose" do
    assert Chat.create!(user: users(:head), household: households(:home), purpose: "listening_game").persisted?
    assert Ai::Use.create!(user: users(:head), purpose: "listening_game").persisted?
  end
end
