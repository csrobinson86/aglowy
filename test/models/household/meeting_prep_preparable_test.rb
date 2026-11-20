require "test_helper"

# household.prepare_meeting_prep (docs/design/meeting-prep.md, The weekly AI job; Traps 1, 3, 4 and 9). Monday 16
# November 2026 at 3am in UTC; the midweek meeting is Tuesday at 7pm and the weekend meeting Sunday at 10am. The provider
# answers through WebMock with the recorded reply in test/fixtures/files/ai/meeting_prep.json: no test calls a
# provider, and nothing reaches jw.org or wol.jw.org.
class Household::MeetingPrepPreparableTest < ActiveSupport::TestCase
  PROVIDER = "https://api.anthropic.com/v1/messages".freeze
  WEEK = Date.new(2026, 11, 16)
  MONDAY = Time.utc(2026, 11, 16, 3)
  PROGRAM = "https://wol.jw.org/en/wol/meetings/r1/lp-e/2026/47".freeze
  SOURCES = [ [ PROGRAM, "Life and Ministry Meeting Workbook, November 16-22" ],
              [ "https://wol.jw.org/en/wol/d/r1/lp-e/202026408", "Treasures From God's Word: Jeremiah keeps hoping" ],
              [ "https://wol.jw.org/en/wol/d/r1/lp-e/2026645", "The Watchtower, study article for November 22" ] ].freeze
  STEPS = %w[ talk bible_reading living congregation_bible_study watchtower_study ].freeze
  STORY = [ "Jerusalem was the city where Jehovah’s people lived.", "The people stopped listening to Jehovah.",
            "An army came and broke the city.", "Jeremiah cried and asked Jehovah to help his people." ].freeze

  setup do
    @household = households(:home)
    @household.change_meeting_times(midweek_wday: 2, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    @household.enable_meeting_helper(by: users(:head))
    @household.enable_meeting_prep(by: users(:spouse))
    travel_to MONDAY
  end

  test "the recorded reply saves the cards and sources" do
    accept users(:head)
    week = prepare.reload

    assert_equal [ @household, WEEK ], [ week.household, week.week_of ]
    assert_equal STEPS, week.cards.map(&:step)
    assert_equal %w[ midweek midweek midweek midweek weekend ], week.cards.map(&:meeting)
    talk = week.cards.first
    assert_equal [ "Jeremiah felt very sad. But he remembered that Jehovah never stops caring.", "caring",
                   "His kindness is new every morning.", "Tell Jehovah when I feel sad.", nil, nil ],
                 [ talk.about, talk.quality, talk.quality_line, talk.i_can, talk.reading, talk.story ]
    reading = week.cards.second
    assert_equal [ "Lamentations 1–2", STORY ], [ reading.reading, reading.story ]
    # The page a citation named that the search never returned is dropped by Ai::SourceLink.
    assert_equal SOURCES, week.sources.map { [ it.url, it.title ] }
    assert_equal [ 1, 2, 3 ], week.sources.map(&:position)
    assert_not_includes week.sources.to_json, "Excerpt"
    assert_equal [ "meeting_prep", users(:head), @household ], [ week.chat.purpose, week.chat.user, week.chat.household ]
    assert_empty PrepWeek::Preparation.all
  end

  test "a second call for the week does nothing" do
    accept users(:head)
    prepare

    assert_no_difference -> { Chat.count } do
      assert_nil @household.prepare_meeting_prep(WEEK)
    end
    assert_requested :post, PROVIDER, times: 1
    assert_equal 5, @household.prep_week_for(WEEK).cards.size
  end

  test "a fresh claim stops a second run" do
    accept users(:head)
    held = claim(created_at: 14.minutes.ago)

    assert_nil prepare
    assert_not_requested :post, PROVIDER
    assert_equal held.token, held.reload.token
    assert_nil @household.prep_week_for(WEEK)
  end

  test "two runs at once send one request: the second finds the first's claim" do
    accept users(:head)
    stub_request(:post, PROVIDER).to_return do
      assert_nil @household.prepare_meeting_prep(WEEK)
      { status: 200, body: reply.to_json, headers: { "Content-Type" => "application/json" } }
    end

    assert @household.prepare_meeting_prep(WEEK)
    assert_requested :post, PROVIDER, times: 1
  end

  test "a claim older than 15 minutes is taken over" do
    accept users(:head)
    stale = claim(created_at: 16.minutes.ago)

    assert prepare
    assert_not PrepWeek::Preparation.exists?(stale.id)
  end

  test "a run whose claim was taken over saves nothing" do
    accept users(:head)
    newer = SecureRandom.uuid
    stub_request(:post, PROVIDER).to_return do
      # Another run takes the claim over while this one's request is out.
      PrepWeek::Preparation.sole.update!(token: newer, created_at: Time.current)
      { status: 200, body: reply.to_json, headers: { "Content-Type" => "application/json" } }
    end

    assert_nil @household.prepare_meeting_prep(WEEK)
    assert_nil @household.prep_week_for(WEEK)
    assert_equal newer, PrepWeek::Preparation.sole.token
  end

  test "nobody has accepted the AI terms: not allowed, no claim, no chat, no request" do
    # A child and someone who has left don't count, whoever accepted.
    [ users(:child), users(:former) ].each { accept it }
    stub_request(:post, PROVIDER)

    assert_no_difference -> { Chat.count } do
      assert_no_queries_match(/INSERT INTO "prep_week_preparations"/) do
        assert_equal :not_allowed, @household.prepare_meeting_prep(WEEK)
      end
    end
    assert_not_requested :post, PROVIDER
  end

  test "the owner is the person who turned Get ready on, when they've accepted the AI terms" do
    [ users(:head), users(:spouse) ].each { accept it }

    assert_equal users(:spouse), prepare.chat.user
  end

  test "the owner is a head before an adult when the person who turned Get ready on hasn't accepted" do
    [ users(:head), users(:spouse) ].each { accept it }
    @household.disable_meeting_prep
    @household.enable_meeting_prep(by: users(:former))

    assert_equal users(:head), prepare.chat.user
  end

  test "the owner skips anyone who hasn't accepted or has left, then takes the oldest adult" do
    joined = @household.add_member(name: "Rosa", role: :adult)
    # The fixtures' memberships are made at today's real time, and this test runs on 16 November.
    joined.update_column(:created_at, 1.year.from_now)
    newer = joined.user
    @household.disable_meeting_prep
    @household.enable_meeting_prep(by: users(:former))
    [ users(:former), users(:spouse), newer ].each { accept it }

    assert_equal users(:spouse), prepare.chat.user
  end

  test "the daily limit: a household that has had its 3 requests today sends no fourth, and yesterday's don't count" do
    accept users(:head)
    travel_to(MONDAY - 4.hours) { meeting_prep_chat }
    2.times { meeting_prep_chat }
    prepare(unusable_reply)

    assert_no_difference -> { Chat.count } do
      assert_nil @household.prepare_meeting_prep(WEEK)
    end
    assert_requested :post, PROVIDER, times: 1
    assert_empty PrepWeek::Preparation.all
  end

  test "a failed request lets the claim go and its chat doesn't count" do
    accept users(:head)
    stub_request(:post, PROVIDER).to_return(status: 500)

    assert_raises(RubyLLM::ServerError) { @household.prepare_meeting_prep(WEEK) }
    assert_empty PrepWeek::Preparation.all
    assert_empty @household.chats.where(purpose: "meeting_prep")
    assert_nil @household.prep_week_for(WEEK)
  end

  test "the question holds the week's dates, the program's address and the missing steps, and nothing goes to jw.org" do
    accept users(:head)
    prepare

    assert_requested(:post, PROVIDER, times: 1) do |request|
      question = JSON.parse(request.body)["messages"].last["content"].pluck("text").join
      [ PROGRAM, "November 16, 2026", "November 22, 2026", STEPS.join(", ") ].all? { question.include?(it) }
    end
    assert_not_requested :any, %r{\Ahttps?://([^/]+\.)?jw\.org}
  end

  # Filling in (The weekly AI job: Filling in, never replacing).

  test "a week missing only its Watchtower card asks for that step alone and keeps the others, including one a parent changed" do
    accept users(:head)
    week = PrepWeek.create!(household: @household, week_of: WEEK)
    STEPS.first(4).each { prep_card(week, it) }
    changed = week.cards.find_by!(step: "talk")
    changed.update!(about: "Jeremiah kept hoping.", changed_by: users(:spouse))

    assert_equal week, prepare
    assert_requested(:post, PROVIDER) { |request| JSON.parse(request.body)["messages"].last["content"].pluck("text").join.include?("cards for: watchtower_study\n") }
    assert_equal STEPS, week.reload.cards.map(&:step)
    assert_equal [ "Jeremiah kept hoping.", users(:spouse) ], [ changed.reload.about, changed.changed_by ]
    assert_equal [ "Jehovah helps us." ] * 3, week.cards[1..3].map(&:about)
    assert_equal "Jehovah wants us to be patient and gentle with our family.", week.cards.last.about
  end

  test "a reply card for a step that wasn't asked for is dropped" do
    accept users(:head)
    week = PrepWeek.create!(household: @household, week_of: WEEK)
    prep_card(week, "talk")

    prepare

    assert_equal "Jehovah helps us.", week.cards.find_by!(step: "talk").about
    assert_equal 5, week.cards.count
  end

  test "a reply card for a step that got a card while the request was out is dropped" do
    accept users(:head)
    week = PrepWeek.create!(household: @household, week_of: WEEK)
    stub_request(:post, PROVIDER).to_return do
      prep_card(week, "living", about: "Saved while the request was out.")
      { status: 200, body: reply.to_json, headers: { "Content-Type" => "application/json" } }
    end

    @household.prepare_meeting_prep(WEEK)

    assert_equal "Saved while the request was out.", week.cards.find_by!(step: "living").about
    assert_equal STEPS, week.reload.cards.map(&:step)
  end

  test "a week with every card makes no request" do
    accept users(:head)
    week = PrepWeek.create!(household: @household, week_of: WEEK)
    STEPS.each { prep_card(week, it) }
    stub_request(:post, PROVIDER)

    assert_no_difference -> { Chat.count } do
      assert_nil @household.prepare_meeting_prep(WEEK)
    end
    assert_not_requested :post, PROVIDER
  end

  test "missing steps: once the midweek meeting has passed only the Watchtower card is missing, and none once both have" do
    week = PrepWeek.create!(household: @household, week_of: WEEK)
    prep_card(week, "talk")

    assert_equal STEPS.drop(1), @household.missing_prep_steps(WEEK, MONDAY)
    # Tuesday's meeting is over on Wednesday; Sunday's at noon.
    assert_equal %w[ watchtower_study ], @household.missing_prep_steps(WEEK, Time.utc(2026, 11, 18, 3))
    assert_empty @household.missing_prep_steps(WEEK, Time.utc(2026, 11, 22, 12))
    assert_equal STEPS, @household.missing_prep_steps(WEEK + 7, MONDAY)
  end

  test "missing steps: none before meeting times are set" do
    households(:other).update_columns(midweek_meeting_wday: nil, midweek_meeting_time: nil, weekend_meeting_wday: nil, weekend_meeting_time: nil)

    assert_empty households(:other).missing_prep_steps(WEEK, MONDAY)
  end

  test "after the midweek meeting, only the Watchtower card is asked for and saved" do
    accept users(:head)
    travel_to Time.utc(2026, 11, 18, 3)

    assert_equal %w[ watchtower_study ], prepare.cards.map(&:step)
  end

  # The reply checks (Checks before saving).

  test "a whitespace-only i_can drops the card" do
    accept users(:head)

    assert_equal STEPS - %w[ living ], prepare(reply { card(it, "living")["i_can"] = " \n\t " }).cards.map(&:step)
  end

  test "an about over 20 words drops the card, and one of 20 is kept" do
    accept users(:head)
    week = prepare(reply do |parsed|
      card(parsed, "talk")["about"] = ([ "Jehovah" ] * 21).join(" ")
      card(parsed, "living")["about"] = ([ "Jehovah" ] * 20).join(" ")
    end)

    assert_equal STEPS - %w[ talk ], week.cards.map(&:step)
  end

  test "a quality_line, an i_can or a story sentence over 14 words drops the card" do
    accept users(:head)
    fifteen = ([ "kind" ] * 15).join(" ")
    week = prepare(reply do |parsed|
      card(parsed, "talk")["quality_line"] = fifteen
      card(parsed, "living")["i_can"] = fifteen
      card(parsed, "bible_reading")["story"][1] = fifteen
    end)

    assert_equal %w[ congregation_bible_study watchtower_study ], week.cards.map(&:step)
  end

  test "a field longer than its column drops the card" do
    accept users(:head)
    week = prepare(reply do |parsed|
      card(parsed, "talk")["about"] = ([ "a" * 10 ] * 15).join(" ")
      card(parsed, "bible_reading")["reading"] = "1 Kings 1–2 and the beginning of 2 Kings 1"
    end)

    assert_equal STEPS - %w[ talk bible_reading ], week.cards.map(&:step)
  end

  test "a missing, one-sentence or five-sentence story drops the Bible Reading card" do
    accept users(:head)

    [ nil, [], STORY.first(1), STORY + [ "Jehovah heard him." ] ].each do |story|
      week = prepare(reply { card(it, "bible_reading")["story"] = story })

      assert_equal STEPS - %w[ bible_reading ], week.cards.map(&:step)
      week.destroy!
      @household.chats.destroy_all
    end
  end

  test "a missing reading drops the Bible Reading card" do
    accept users(:head)

    assert_equal STEPS - %w[ bible_reading ], prepare(reply { card(it, "bible_reading")["reading"] = "" }).cards.map(&:step)
  end

  test "the next run asks for a dropped Bible Reading card again, and saves it" do
    accept users(:head)
    week = prepare(reply { card(it, "bible_reading")["story"] = STORY.first(1) })

    travel_to MONDAY + 1.day
    prepare

    assert_requested(:post, PROVIDER) { |request| JSON.parse(request.body)["messages"].last["content"].pluck("text").join.include?("cards for: bible_reading\n") }
    assert_equal STEPS, week.reload.cards.map(&:step)
    assert_equal STORY, week.cards.second.story
  end

  test "fewer cards: the week is saved with the ones there are" do
    accept users(:head)
    week = prepare(reply { it["cards"] = it["cards"].values_at(0, 4) })

    assert_equal %w[ talk watchtower_study ], week.reload.cards.map(&:step)
    assert_equal STEPS.values_at(1, 2, 3), @household.missing_prep_steps(WEEK, MONDAY)
  end

  test "a repeated step keeps the first card for it" do
    accept users(:head)
    week = prepare(reply { |parsed| parsed["cards"] << card(parsed, "talk").merge("about" => "Jeremiah again.") })

    assert_equal STEPS, week.cards.map(&:step)
    assert_equal "Jeremiah felt very sad. But he remembered that Jehovah never stops caring.", week.cards.first.about
  end

  test "an unknown quality or step drops the card" do
    accept users(:head)
    week = prepare(reply do |parsed|
      card(parsed, "living")["quality"] = "brave"
      card(parsed, "talk")["step"] = "public_talk"
    end)

    assert_equal STEPS - %w[ talk living ], week.cards.map(&:step)
  end

  test "a story or a reading on the wrong step drops the card" do
    accept users(:head)
    week = prepare(reply do |parsed|
      card(parsed, "talk")["story"] = STORY.first(2)
      card(parsed, "living")["reading"] = "Lamentations 1–2"
    end)

    assert_equal STEPS - %w[ talk living ], week.cards.map(&:step)
  end

  test "the copy check removing about drops the card" do
    accept users(:head)
    copied = "Jehovah made the sun and the moon and the stars too."
    week = prepare(reply(citations: [ "In the beginning Jehovah made the sun and the moon and the stars too, and all." ]) do |parsed|
      card(parsed, "living")["about"] = copied
    end)

    assert_equal STEPS - %w[ living ], week.cards.map(&:step)
  end

  test "the copy check removing a story sentence keeps the card with 3, and drops it at 1" do
    accept users(:head)
    excerpt = [ "Then Jeremiah cried and asked Jehovah to help his people, it says." ]
    week = prepare(reply(citations: excerpt))

    assert_equal STORY.first(3), week.cards.second.story

    week.destroy!
    week = prepare(reply(citations: excerpt) { card(it, "bible_reading")["story"] = STORY.values_at(0, 3) })

    assert_equal STEPS - %w[ bible_reading ], week.cards.map(&:step)
  end

  test "a copied run across two story sentences drops the Bible Reading card" do
    accept users(:head)
    week = prepare(reply(citations: [ "So the people stopped listening to Jehovah. An army came and broke the city walls." ]))

    assert_equal STEPS - %w[ bible_reading ], week.cards.map(&:step)
    assert_equal [ "bible_reading" ], @household.missing_prep_steps(WEEK, MONDAY)
  end

  test "a link in a card's text or a story sentence drops the card" do
    accept users(:head)
    week = prepare(reply do |parsed|
      card(parsed, "talk")["about"] = "Read more at https://example.com today."
      card(parsed, "living")["i_can"] = "Visit www.example.com with Mom."
      card(parsed, "bible_reading")["story"][2] = "See wol.jw.org/en for the city."
    end)

    assert_equal %w[ congregation_bible_study watchtower_study ], week.cards.map(&:step)
  end

  test "nothing usable saves nothing and lets the claim go" do
    accept users(:head)

    assert_no_difference -> { PrepWeek.count } do
      assert_nil prepare(reply { it["cards"].each { |each_card| each_card["quality"] = "brave" } })
      assert_nil prepare(unusable_reply)
    end
    assert_empty PrepWeek::Preparation.all
  end

  private
    def accept(user)
      user.accept_ai_terms(understood: true)
    end

    def prepare(body = reply)
      stub_request(:post, PROVIDER).to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
      @household.prepare_meeting_prep(WEEK)
    end

    def claim(created_at:)
      PrepWeek::Preparation.create!(household: @household, week_of: WEEK, token: SecureRandom.uuid, created_at:)
    end

    def meeting_prep_chat
      Chat.create!(user: users(:head), household: @household, purpose: "meeting_prep")
    end

    def card(parsed, step)
      parsed["cards"].find { it["step"] == step }
    end

    # The recorded reply as the provider sends it. With a block or +citations+, its parsed fields (changed by the block)
    # go in one text block, followed by an empty one carrying a citation for each of +citations+, so the copy check has
    # excerpts to compare.
    def reply(citations: [])
      body = JSON.parse(file_fixture("ai/meeting_prep.json").read)
      return body unless block_given? || citations.any?

      texts, others = body["content"].partition { it["type"] == "text" }
      parsed = JSON.parse(texts.pluck("text").join).tap { yield it if block_given? }
      cited = citations.map { { "type" => "web_search_result_location", "url" => PROGRAM, "title" => SOURCES.first.last, "cited_text" => it } }
      body.merge("content" => others + [ { "type" => "text", "text" => parsed.to_json }, { "type" => "text", "text" => "", "citations" => cited } ])
    end

    # Off topic, with no cards: a reply the provider answered, with nothing to save.
    def unusable_reply
      reply.merge("content" => [ { "type" => "text", "text" => { off_topic: true, cards: [] }.to_json } ])
    end
end
