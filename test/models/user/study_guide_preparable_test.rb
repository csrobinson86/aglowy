require "test_helper"

# user.prepare_study_guide (docs/design/study-guide.md, The weekly job and Ai::Purpose::StudyGuide; Traps 1, 2, 5 and
# 7). Monday 16 November 2026 at 3am in UTC, the head's time zone. The provider answers through WebMock with the recorded
# reply in test/fixtures/files/ai/study_guide.json: no test calls a provider, and nothing reaches jw.org or wol.jw.org.
class User::StudyGuidePreparableTest < ActiveSupport::TestCase
  PROVIDER = "https://api.anthropic.com/v1/messages".freeze
  WEEK = Date.new(2026, 11, 16)
  MONDAY = Time.utc(2026, 11, 16, 3)
  PROGRAM = "https://wol.jw.org/en/wol/meetings/r1/lp-e/2026/47".freeze
  SOURCES = [ [ PROGRAM, "Life and Ministry Meeting Workbook, November 16-22" ],
              [ "https://wol.jw.org/en/wol/b/r1/lp-e/nwtsty/25/1", "Lamentations 1" ],
              [ "https://wol.jw.org/en/wol/d/r1/lp-e/1102026070", "Congregation Bible Study, chapter 7" ],
              [ "https://wol.jw.org/en/wol/d/r1/lp-e/2026645", "The Watchtower, study article for November 22" ] ].freeze
  STEPS = %w[ midweek_overview talk spiritual_gems bible_reading field_ministry living congregation_bible_study
              weekend_overview watchtower_study ].freeze

  setup do
    @user = users(:head)
    travel_to MONDAY
  end

  test "the recorded reply saves the parts and sources" do
    accept
    guide = prepare.reload

    assert_equal [ @user, WEEK ], [ guide.user, guide.week_of ]
    assert_equal STEPS, guide.parts.map(&:step)
    overview = guide.parts.first.content
    assert_equal "Jeremiah grieves over Jerusalem, yet holds on to Jehovah’s mercy. The program asks how we keep hope when things go wrong, and how we comfort others who are hurting.",
                 overview["glance"]
    assert_equal [ [ "Merciful", "Lamentations 1:20" ], [ "Just", "Lamentations 1:18" ], [ "Faithful", "Lamentations 2:17" ] ],
                 overview["jehovah"].map { it.values_at("quality", "ref") }
    reading = guide.parts.find { it.step == "bible_reading" }.content
    assert_equal "Lamentations 1–2", reading["reading"]
    # References are kept our way, and a point without one has no ref.
    assert_equal [ "Lamentations 1:1-7", "Lamentations 2:18, 19" ], reading["happens"].pluck("ref")
    assert_equal [ { "text" => "Tell Jehovah how we really feel, as Jeremiah did." }, { "text" => "Take his warnings seriously while there is time." } ], reading["apply"]
    study = guide.parts.find { it.step == "congregation_bible_study" }.content
    assert_equal [ "Jehovah Is Near Those Who Hurt", %w[ 1–3 4–7 8–10 ], "5" ], [ study["title"], study["notes"].pluck("paragraphs"), study["comments"].first["paragraph"] ]
    # The page a citation named that the search never returned is dropped by Ai::SourceLink.
    assert_equal SOURCES, guide.sources.map { [ it.url, it.title ] }
    assert_equal [ 1, 2, 3, 4 ], guide.sources.map(&:position)
    assert_not_includes guide.sources.to_json, "Excerpt"
    assert_equal [ "study_guide", @user, nil ], [ guide.chat.purpose, guide.chat.user, guide.chat.household ]
    assert_empty StudyGuide::Preparation.all
  end

  test "study_guide_for reads the week with its parts and sources, or nil" do
    accept
    prepare

    assert_equal STEPS, @user.study_guide_for(WEEK).parts.map(&:step)
    assert_nil @user.study_guide_for(WEEK + 7)
    assert_nil users(:spouse).study_guide_for(WEEK)
  end

  test "a second call for the week adds nothing" do
    accept
    prepare

    assert_no_difference -> { Chat.count } do
      assert_nil @user.prepare_study_guide(WEEK)
    end
    assert_requested :post, PROVIDER, times: 1
    assert_equal 9, @user.study_guide_for(WEEK).parts.size
  end

  test "a fresh claim stops a second run" do
    accept
    held = claim(created_at: 14.minutes.ago)

    assert_nil prepare
    assert_not_requested :post, PROVIDER
    assert_equal held.token, held.reload.token
    assert_nil @user.study_guide_for(WEEK)
  end

  test "two runs at once send one request: the second finds the first's claim" do
    accept
    stub_request(:post, PROVIDER).to_return do
      assert_nil @user.prepare_study_guide(WEEK)
      { status: 200, body: reply.to_json, headers: { "Content-Type" => "application/json" } }
    end

    assert @user.prepare_study_guide(WEEK)
    assert_requested :post, PROVIDER, times: 1
  end

  test "a claim older than 15 minutes is taken over" do
    accept
    stale = claim(created_at: 16.minutes.ago)

    assert prepare
    assert_not StudyGuide::Preparation.exists?(stale.id)
  end

  test "a run whose claim was taken over saves nothing" do
    accept
    newer = SecureRandom.uuid
    stub_request(:post, PROVIDER).to_return do
      # Another run takes the claim over while this one's request is out.
      StudyGuide::Preparation.sole.update!(token: newer, created_at: Time.current)
      { status: 200, body: reply.to_json, headers: { "Content-Type" => "application/json" } }
    end

    assert_nil @user.prepare_study_guide(WEEK)
    assert_nil @user.study_guide_for(WEEK)
    assert_equal newer, StudyGuide::Preparation.sole.token
  end

  test "no accepted AI terms: not allowed, no claim, no chat, no request" do
    stub_request(:post, PROVIDER)

    assert_no_difference -> { Chat.count } do
      assert_no_queries_match(/INSERT INTO "study_guide_preparations"/) do
        assert_equal :not_allowed, @user.prepare_study_guide(WEEK)
      end
    end
    assert_not_requested :post, PROVIDER
  end

  test "the daily limit: a person who has had their 2 requests today sends no third, and yesterday's don't count" do
    accept
    travel_to(MONDAY - 4.hours) { study_guide_chat }
    study_guide_chat
    prepare(unusable_reply)

    assert_no_difference -> { Chat.count } do
      assert_nil @user.prepare_study_guide(WEEK)
    end
    assert_requested :post, PROVIDER, times: 1
    assert_empty StudyGuide::Preparation.all
  end

  test "the daily limit counts from midnight where the person lives" do
    accept
    @user.update!(time_zone: "Pacific Time (US & Canada)")
    # 3am UTC on Monday is still Sunday in California, so a chat at 9am UTC on Sunday is today's there.
    travel_to(MONDAY - 18.hours) { 2.times { study_guide_chat } }
    stub_request(:post, PROVIDER)

    assert_nil @user.prepare_study_guide(WEEK)
    assert_not_requested :post, PROVIDER
  end

  test "a failed request lets the claim go and its chat doesn't count" do
    accept
    stub_request(:post, PROVIDER).to_return(status: 500)

    assert_raises(RubyLLM::ServerError) { @user.prepare_study_guide(WEEK) }
    assert_empty StudyGuide::Preparation.all
    assert_empty @user.chats.where(purpose: "study_guide")
    assert_nil @user.study_guide_for(WEEK)
  end

  test "the question holds the week's dates, the program's address as text and the missing steps, and nothing goes to jw.org" do
    accept
    prepare

    assert_requested(:post, PROVIDER, times: 1) do |request|
      question = question_in(request)
      [ PROGRAM, "November 16, 2026", "November 22, 2026", STEPS.join(", ") ].all? { question.include?(it) }
    end
    assert_not_requested :any, %r{\Ahttps?://([^/]+\.)?jw\.org}
  end

  # Filling in, never replacing (The weekly job).

  test "a week missing only watchtower_study asks for that step alone and keeps the rest" do
    accept
    guide = StudyGuide.create!(user: @user, week_of: WEEK)
    (STEPS - %w[ watchtower_study ]).each { guide_part(guide, it) }
    kept = guide.parts.find_by!(step: "talk").content

    assert_equal guide, prepare
    assert_requested(:post, PROVIDER) { question_in(it).include?("parts for: watchtower_study\n") }
    assert_equal STEPS, guide.reload.parts.map(&:step)
    assert_equal kept, guide.parts.find_by!(step: "talk").content
    assert_equal "Be Patient With One Another", guide.parts.last.content["title"]
    assert_empty @user.missing_study_guide_steps(WEEK)
  end

  test "a reply part for a step that wasn't asked for is dropped" do
    accept
    guide = StudyGuide.create!(user: @user, week_of: WEEK)
    guide_part(guide, "talk")

    prepare

    assert_equal "A part to keep.", guide.parts.find_by!(step: "talk").content["summary"]
    assert_equal 9, guide.parts.count
  end

  test "a reply part for a step that got a part while the request was out is dropped" do
    accept
    guide = StudyGuide.create!(user: @user, week_of: WEEK)
    stub_request(:post, PROVIDER).to_return do
      guide_part(guide, "living")
      { status: 200, body: reply.to_json, headers: { "Content-Type" => "application/json" } }
    end

    @user.prepare_study_guide(WEEK)

    assert_equal "A part to keep.", guide.parts.find_by!(step: "living").content["summary"]
    assert_equal STEPS, guide.reload.parts.map(&:step)
  end

  test "a week with every part makes no request" do
    accept
    guide = StudyGuide.create!(user: @user, week_of: WEEK)
    STEPS.each { guide_part(guide, it) }
    stub_request(:post, PROVIDER)

    assert_no_difference -> { Chat.count } do
      assert_nil @user.prepare_study_guide(WEEK)
    end
    assert_not_requested :post, PROVIDER
  end

  test "missing steps: all nine for a week with no guide, the rest once some are saved" do
    assert_equal STEPS, @user.missing_study_guide_steps(WEEK)

    guide = StudyGuide.create!(user: @user, week_of: WEEK)
    guide_part(guide, "talk")

    assert_equal STEPS - %w[ talk ], @user.missing_study_guide_steps(WEEK)
    assert_equal STEPS, @user.missing_study_guide_steps(WEEK + 7)
    assert_equal STEPS, users(:spouse).missing_study_guide_steps(WEEK)
  end

  # The reply checks (Checks before saving).

  test "a summary removed by the copy check drops the part, and the next run asks for it again" do
    accept
    summary = "Jeremiah mourns Jerusalem after its destruction, picturing the city as a widow left alone."
    guide = prepare(reply(citations: [ "Here Jeremiah mourns Jerusalem after its destruction, picturing the city as a widow." ]))

    assert_equal STEPS - %w[ bible_reading ], guide.parts.map(&:step)
    assert_equal [ "bible_reading" ], @user.missing_study_guide_steps(WEEK)

    travel_to MONDAY + 1.day
    prepare

    assert_requested(:post, PROVIDER) { question_in(it).include?("parts for: bible_reading\n") }
    assert_equal summary, guide.reload.parts.find { it.step == "bible_reading" }.content["summary"]
  end

  test "a Bible Reading part without its reading is dropped" do
    accept

    assert_equal STEPS - %w[ bible_reading ], prepare(reply { content(it, "bible_reading")["reading"] = " " }).parts.map(&:step)
  end

  test "an overview without its glance, or a part without its summary, is dropped" do
    accept
    guide = prepare(reply do |parsed|
      content(parsed, "weekend_overview").delete("glance")
      content(parsed, "living")["summary"] = ""
    end)

    assert_equal STEPS - %w[ living weekend_overview ], guide.parts.map(&:step)
  end

  test "an item the copy check removes goes, and the part stays" do
    accept
    guide = prepare(reply(citations: [ "And so Jerusalem lies empty; its people are gone and its enemies mock it, they say." ]))

    happens = guide.parts.find { it.step == "bible_reading" }.content["happens"]
    assert_equal [ "Jeremiah weeps and calls on the people to cry out to Jehovah." ], happens.pluck("text")
  end

  test "a quotation longer than 5 words removes its item" do
    accept
    guide = prepare(reply { content(it, "talk")["points"][1]["text"] = "He said “I will hope in him, my portion” then." })

    assert_equal [ "Jerusalem’s fall was hard, but it wasn’t the end of Jehovah’s care." ], guide.parts.find { it.step == "talk" }.content["points"].pluck("text")
  end

  test "a reference that doesn't parse is dropped and its point kept" do
    accept
    guide = prepare(reply do |parsed|
      content(parsed, "talk")["points"][0]["ref"] = "Lamentations 9:99"
      content(parsed, "midweek_overview")["jehovah"][0]["ref"] = "Hezekiah 3:1"
    end)

    point = guide.parts.find { it.step == "talk" }.content["points"].first
    assert_equal({ "text" => "Jerusalem’s fall was hard, but it wasn’t the end of Jehovah’s care." }, point)
    assert_equal({ "quality" => "Merciful", "text" => "He still hears his people when they cry out to him in their distress." },
                 guide.parts.first.content["jehovah"].first)
  end

  test "a whole chapter is a reference that parses" do
    accept
    guide = prepare(reply { content(it, "living")["apply"][0]["ref"] = "Psalm 23" })

    assert_equal "Psalm 23", guide.parts.find { it.step == "living" }.content["apply"].first["ref"]
  end

  test "an item over 30 words drops the item, and one of 30 is kept" do
    accept
    guide = prepare(reply do |parsed|
      content(parsed, "bible_reading")["apply"][0]["text"] = ([ "Jehovah" ] * 31).join(" ")
      content(parsed, "bible_reading")["apply"][1]["text"] = ([ "Jehovah" ] * 30).join(" ")
    end)

    assert_equal [ ([ "Jehovah" ] * 30).join(" ") ], guide.parts.find { it.step == "bible_reading" }.content["apply"].pluck("text")
  end

  test "a summary over 50 words or a glance over 40 drops the part" do
    accept
    guide = prepare(reply do |parsed|
      content(parsed, "talk")["summary"] = ([ "Jehovah" ] * 51).join(" ")
      content(parsed, "midweek_overview")["glance"] = ([ "Jehovah" ] * 41).join(" ")
    end)

    assert_equal STEPS - %w[ midweek_overview talk ], guide.parts.map(&:step)
  end

  test "a title over 12 words goes, and the part stays" do
    accept
    guide = prepare(reply { content(it, "living")["title"] = ([ "Comfort" ] * 13).join(" ") })

    assert_equal %w[ summary apply ], guide.parts.find { it.step == "living" }.content.keys
  end

  test "a list keeps its first items up to its most, and an overview item without its quality goes" do
    accept
    guide = prepare(reply do |parsed|
      content(parsed, "talk")["points"] *= 3
      content(parsed, "midweek_overview")["jehovah"][1]["quality"] = ""
    end)

    assert_equal 4, guide.parts.find { it.step == "talk" }.content["points"].size
    assert_equal %w[ Merciful Faithful ], guide.parts.first.content["jehovah"].pluck("quality")
  end

  test "one comment idea drops Spiritual Gems" do
    accept

    assert_equal STEPS - %w[ spiritual_gems ], prepare(reply { content(it, "spiritual_gems")["comments"].pop(2) }).parts.map(&:step)
  end

  test "a web address in a point is taken out, and the point kept" do
    accept
    guide = prepare(reply { content(it, "living")["apply"][0]["text"] = "Send a short card to someone, see https://example.com/cards today." })

    assert_equal "Send a short card to someone, see today.", guide.parts.find { it.step == "living" }.content["apply"].first["text"]
  end

  test "a repeated step keeps the first part for it, and an unknown step is dropped" do
    accept
    guide = prepare(reply do |parsed|
      parsed["parts"] << { "step" => "talk", "content" => content(parsed, "talk").merge("summary" => "Again.") }
      parsed["parts"] << { "step" => "public_talk", "content" => content(parsed, "talk") }
    end)

    assert_equal STEPS, guide.parts.map(&:step)
    assert_equal "The talk shows how Jeremiah, though grieving, kept trusting that Jehovah would show mercy again.", guide.parts.second.content["summary"]
  end

  test "nothing usable saves nothing and lets the claim go" do
    accept

    assert_no_difference -> { StudyGuide.count } do
      assert_nil prepare(reply { it["parts"].each { |part| part["content"]["summary"] = part["content"]["glance"] = "" } })
      assert_nil prepare(unusable_reply)
    end
    assert_empty StudyGuide::Preparation.all
  end

  private
    def accept
      @user.accept_ai_terms(understood: true)
    end

    def prepare(body = reply)
      stub_request(:post, PROVIDER).to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
      @user.prepare_study_guide(WEEK)
    end

    def claim(created_at:)
      StudyGuide::Preparation.create!(user: @user, week_of: WEEK, token: SecureRandom.uuid, created_at:)
    end

    def study_guide_chat
      Chat.create!(user: @user, purpose: "study_guide")
    end

    def guide_part(guide, step)
      guide.parts.create!(step:, content: valid_study_guide_content(step))
    end

    def question_in(request)
      JSON.parse(request.body)["messages"].last["content"].pluck("text").join
    end

    def content(parsed, step)
      parsed["parts"].find { it["step"] == step }["content"]
    end

    # The recorded reply as the provider sends it. With a block or +citations+, its parsed fields (changed by the block)
    # go in one text block, followed by an empty one carrying a citation for each of +citations+, so the copy check has
    # excerpts to compare.
    def reply(citations: [])
      body = JSON.parse(file_fixture("ai/study_guide.json").read)
      return body unless block_given? || citations.any?

      texts, others = body["content"].partition { it["type"] == "text" }
      parsed = JSON.parse(texts.pluck("text").join).tap { yield it if block_given? }
      cited = citations.map { { "type" => "web_search_result_location", "url" => PROGRAM, "title" => SOURCES.first.last, "cited_text" => it } }
      body.merge("content" => others + [ { "type" => "text", "text" => parsed.to_json }, { "type" => "text", "text" => "", "citations" => cited } ])
    end

    # Off topic, with no parts: a reply the provider answered, with nothing to save.
    def unusable_reply
      reply.merge("content" => [ { "type" => "text", "text" => { off_topic: true, parts: [] }.to_json } ])
    end
end
