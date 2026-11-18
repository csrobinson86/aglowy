require "test_helper"

# household.prepare_listening_game (docs/design/listening-game.md, The weekly research job, What it asks). The provider
# answers through WebMock with the recorded reply in test/fixtures/files/ai/listening_game.json: no test calls a provider,
# and nothing reaches jw.org or wol.jw.org (Traps 1 and 10).
class Household::ListeningGamePreparingTest < ActiveSupport::TestCase
  PROVIDER = "https://api.anthropic.com/v1/messages".freeze
  WEEK = Date.new(2026, 11, 16)
  PROGRAM = "https://wol.jw.org/en/wol/meetings/r1/lp-e/2026/47".freeze
  SOURCES = [ [ PROGRAM, "Life and Ministry Meeting Workbook, November 16-22" ],
              [ "https://wol.jw.org/en/wol/d/r1/lp-e/202026408", "Treasures From God's Word: Jeremiah keeps hoping" ],
              [ "https://wol.jw.org/en/wol/d/r1/lp-e/1102021120", "Congregation Bible Study: chapter 20" ] ].freeze

  setup do
    @household = households(:home)
    @household.enable_meeting_helper(by: users(:spouse))
  end

  test "the recorded reply saves the steps, rounds and cards in order, each round with one answer" do
    accept users(:head)
    game = prepare.reload

    assert_equal [ @household, WEEK ], [ game.household, game.week_of ]
    answers = game.rounds.group_by(&:step).transform_values { |rounds| rounds.map { it.answer.label } }
    assert_equal({ "talk" => [ "Jeremiah", "Tears", "A scroll", "Praying to Jehovah", "Saying sorry to Jehovah" ],
                   "spiritual_gems" => [ "Jerusalem", "Hoping in Jehovah" ], "bible_reading" => [ "Lamentations" ],
                   "congregation_bible_study" => [ "Jesus", "A fishing boat", "Peter", "Galilee", "Helping people", "Being kind" ] }, answers)
    game.rounds.group_by(&:step).each_value { |rounds| assert_equal (1..rounds.size).to_a, rounds.map(&:position) }
    game.rounds.each do |round|
      assert_equal [ 1, 2, 3, 4 ], round.cards.map(&:position)
      assert_equal 1, round.cards.count(&:answer)
    end
    assert_equal %w[ Daniel Jeremiah Moses Noah ], game.rounds.first.cards.map(&:label).sort
    assert_equal %w[ person ], game.rounds.first.cards.map(&:kind).uniq
    # Shuffled into the grid, so the answer isn't always first.
    assert_not game.rounds.all? { it.answer.position == 1 }
  end

  test "a round with two answers, two others, a repeated label, a bad kind, a long label or a label the copy check removed is dropped and the rest are kept" do
    accept users(:head)
    copied = "God made the sun and the moon too"
    game = prepare(reply(citations: [ "In the beginning God made the sun and the moon too, and the stars." ]) do |parsed|
      talk = parsed["talk"]
      talk[0]["answer"] = [ talk[0]["answer"], talk[0]["others"].first ]
      talk[1]["others"][2]["label"] = "a rainbow"
      talk[2]["others"][0]["kind"] = "animal"
      talk[3]["answer"]["label"] = "Praying to Jehovah with all of the family"
      talk[4]["answer"]["label"] = copied
      parsed["bible_reading"][0]["others"].pop
    end).reload

    assert_equal %w[ spiritual_gems congregation_bible_study ], game.rounds.map(&:step).uniq
    assert_equal [ 1, 2 ], game.rounds.select { it.step == "spiritual_gems" }.map(&:position)
    assert_not ListeningGame::Card.exists?(label: copied)
  end

  test "rounds after a dropped one move up, so positions stay 1, 2, 3" do
    accept users(:head)
    game = prepare(reply { it["talk"][1]["answer"]["kind"] = "animal" }).reload

    talk = game.rounds.select { it.step == "talk" }
    assert_equal [ 1, 2, 3, 4 ], talk.map(&:position)
    assert_equal [ "Jeremiah", "A scroll", "Praying to Jehovah", "Saying sorry to Jehovah" ], talk.map { it.answer.label }
  end

  test "a reply with no usable rounds saves nothing" do
    accept users(:head)

    assert_no_difference -> { ListeningGame.count } do
      assert_nil prepare(reply { |parsed| ListeningGame::STEPS.each { parsed[it] = [] }
                                          parsed["talk"] = [ { "answer" => { "label" => "Jeremiah", "kind" => "person" }, "others" => [] } ] })
    end
  end

  test "an off-topic reply saves nothing" do
    accept users(:head)

    assert_no_difference -> { ListeningGame.count } do
      assert_nil prepare(reply { it["off_topic"] = true })
    end
  end

  test "the chat's purpose, user and household" do
    accept users(:head)
    game = prepare

    assert_equal [ "listening_game", users(:head), @household ], [ game.chat.purpose, game.chat.user, game.chat.household ]
  end

  test "the owner is the person who turned the helper on, when they've accepted the AI terms" do
    [ users(:head), users(:spouse) ].each { accept it }

    assert_equal users(:spouse), prepare.chat.user
  end

  test "the owner is a head before an adult when the person who turned it on hasn't accepted" do
    [ users(:head), users(:spouse) ].each { accept it }
    @household.disable_meeting_helper
    @household.enable_meeting_helper(by: users(:former))

    assert_equal users(:head), prepare.chat.user
  end

  test "the owner skips anyone who hasn't accepted the AI terms or has left, then takes the oldest adult" do
    newer = @household.add_member(name: "Rosa", role: :adult).user
    @household.disable_meeting_helper
    @household.enable_meeting_helper(by: users(:former))
    [ users(:former), users(:spouse), newer ].each { accept it }

    assert_equal users(:spouse), prepare.chat.user
  end

  test "nobody has accepted the AI terms: not allowed, no chat, no provider call" do
    # A child and someone who has left don't count, whoever accepted.
    [ users(:child), users(:former) ].each { accept it }
    stub_request(:post, PROVIDER)

    assert_no_difference -> { Chat.count } do
      assert_equal :not_allowed, @household.prepare_listening_game(WEEK)
    end
    assert_not_requested :post, PROVIDER
  end

  test "every source that passes Ai::SourceLink is saved in order, with no page text" do
    accept users(:head)
    game = prepare.reload

    assert_equal SOURCES, game.sources.map { [ it.url, it.title ] }
    assert_equal [ 1, 2, 3 ], game.sources.map(&:position)
    assert_equal %w[ created_at id listening_game_id position title updated_at url ], ListeningGame::Source.column_names.sort
    assert_not_includes game.sources.to_json, "Excerpt"
  end

  test "a page whose search result has no title is left out, and the rest are saved" do
    accept users(:head)
    body = reply
    body["content"].find { it["type"] == "web_search_tool_result" }["content"].second.delete("title")

    assert_equal [ SOURCES.first, SOURCES.last ], prepare(body).reload.sources.map { [ it.url, it.title ] }
  end

  test "the question holds the week's dates and the program's URL, and no HTTP request goes to jw.org or wol.jw.org" do
    accept users(:head)
    prepare

    assert_requested(:post, PROVIDER, times: 1) do |request|
      question = JSON.parse(request.body)["messages"].last["content"].pluck("text").join
      [ PROGRAM, "November 16, 2026", "November 22, 2026" ].all? { question.include?(it) }
    end
    assert_not_requested :any, %r{\Ahttps?://([^/]+\.)?jw\.org}
  end

  private
    def accept(user)
      user.accept_ai_terms(understood: true)
    end

    def prepare(body = reply)
      stub_request(:post, PROVIDER).to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
      @household.prepare_listening_game(WEEK)
    end

    # The recorded reply as the provider sends it. With a block, its parsed fields change and go in one text block,
    # followed by an empty one carrying a citation for each of +citations+, so the copy check has excerpts to compare.
    def reply(citations: [])
      body = JSON.parse(file_fixture("ai/listening_game.json").read)
      return body unless block_given?

      texts, others = body["content"].partition { it["type"] == "text" }
      parsed = JSON.parse(texts.pluck("text").join).tap { yield it }
      cited = citations.map { { "type" => "web_search_result_location", "url" => PROGRAM, "title" => SOURCES.first.last, "cited_text" => it } }
      body.merge("content" => others + [ { "type" => "text", "text" => parsed.to_json }, { "type" => "text", "text" => "", "citations" => cited } ])
    end
end
