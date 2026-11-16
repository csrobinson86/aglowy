require "test_helper"

class FamilyStudy::Draft::WriteTest < ActiveSupport::TestCase
  # What Ai::Reply reads from RubyLLM's message: the parsed reply, its citations and the pages the search returned.
  Message = Data.define(:parsed, :citations, :web_sources)

  FAMILY_WORSHIP = "https://www.jw.org/en/bible-teachings/family/family-worship/".freeze
  PRAYING_TOGETHER = "https://wol.jw.org/en/wol/d/r1/lp-e/1200275025".freeze
  MADE_UP = "https://www.jw.org/en/bible-teachings/questions/an-article-the-search-never-returned/".freeze
  EXCERPT = "Families who pray together each evening find that their worries feel lighter and their bond grows stronger.".freeze
  COPIED = "Families who pray together each evening find that their worries feel lighter.".freeze
  CHUNKS = [ '{"off_topic":false,"title":"Talking to ', 'Jehovah as a family","opening":' ].freeze

  setup do
    @draft = family_study_draft
  end

  test "flagged: flagged, and the AI is never called" do
    write(->(*, **) { flunk "the AI was called" }, flagged: true)

    assert_predicate @draft.reload, :flagged?
    assert_nil @draft.outline
  end

  test "a draft stopped before its job ran never reaches moderation or the AI" do
    @draft.stop

    Ai::Moderation.stub(:flagged?, ->(*) { flunk "moderation was called" }) do
      @draft.chat.stub(:ask_within_purpose, ->(*, **) { flunk "the AI was called" }) { @draft.write_now }
    end

    assert_predicate @draft.reload, :stopped?
  end

  test "off topic: off_topic, with no outline" do
    write(reply(off_topic: true, title: "", opening: { scripture: "", question: "" }, points: [], children: "", closing: ""))

    assert_predicate @draft.reload, :off_topic?
    assert_nil @draft.outline
    assert_empty @draft.sources
  end

  test "good: drafted, with outline and sources; a bad reference, a copied sentence and a made-up link are gone" do
    write(reply)

    assert_predicate @draft.reload, :drafted?
    outline = @draft.outline
    assert_equal "Talking to Jehovah as a family", outline["title"]
    assert_equal "Philippians 4:6, 7", outline.dig("opening", "scripture")
    assert_equal [ "Psalm 65:2", nil, "1 Peter 5:7" ], outline["points"].pluck("scripture")
    assert_equal "What could we pray about together?", outline["points"].last["question"]
    assert_not_includes outline.to_json, "Hezekiah"
    assert_not_includes outline.to_json, "worries feel lighter"
    assert_equal [ { "url" => FAMILY_WORSHIP, "title" => "Family Worship" }, { "url" => PRAYING_TOGETHER, "title" => "Praying Together as a Family" } ],
                 @draft.sources
    assert_not_includes @draft.sources.to_json, EXCERPT
    assert_not_includes FamilyStudy::Draft.connection.select_value(FamilyStudy::Draft.where(id: @draft.id).select("outline::text").to_sql), "Jehovah"
  end

  test "good: the request sends only the person's text and options" do
    sent = nil
    write(->(text, **) { sent = text
                         reply })

    assert_equal "Prayer as a family\n\nLength: 30 minutes.", sent
  end

  test "the children's activity is kept only when young children were asked for" do
    write(reply(children: "Draw something you want to thank Jehovah for."))
    assert_nil @draft.reload.outline["children"]

    sent = nil
    @draft = family_study_draft(young_children: true)
    write(->(text, **) { sent = text
                         reply(children: "Draw something you want to thank Jehovah for.") })
    assert_equal "Draw something you want to thank Jehovah for.", @draft.reload.outline["children"]
    assert_equal "Prayer as a family\n\nLength: 30 minutes.\nInclude one activity for young children.", sent
  end

  test "fewer than 2 points after the checks: failed" do
    write(reply(points: [ point("Jehovah listens to each of us", "Psalm 65:2", "Why does it matter that Jehovah hears short prayers?"), point(COPIED, "1 Peter 5:7", COPIED) ]))

    assert_predicate @draft.reload, :failed?
    assert_nil @draft.outline
  end

  test "provider error: failed" do
    write(->(*, **) { raise RubyLLM::OverloadedError, "Overloaded" })

    assert_predicate @draft.reload, :failed?
    assert_nil @draft.outline
  end

  test "a reply that isn't a JSON object: failed" do
    write(->(*, **) { raise Ai::Reply::Malformed, "The reply isn't a JSON object" })

    assert_predicate @draft.reload, :failed?
  end

  test "any other error: failed, and raised so it's seen" do
    assert_raises(NoMethodError) { write(->(*, **) { raise NoMethodError, "a bug" }) }

    assert_predicate @draft.reload, :failed?
  end

  test "stopped mid-stream: stays stopped, with no outline" do
    streamed_to_the_end = false
    ask = lambda do |*, stream:|
      stream.call(chunk(CHUNKS.first))
      FamilyStudy::Draft.find(@draft.id).stop
      stream.call(chunk(CHUNKS.last))
      streamed_to_the_end = true
      reply
    end

    write(ask)

    assert_not streamed_to_the_end
    assert_predicate @draft.reload, :stopped?
    assert_nil @draft.outline
  end

  test "stopped after the reply arrived but before the final write: stays stopped, with no outline and no result broadcast" do
    write(->(*, **) { FamilyStudy::Draft.find(@draft.id).stop
                      reply })

    assert_predicate @draft.reload, :stopped?
    assert_nil @draft.outline
    assert_empty streamed("replace")
  end

  test "no broadcast during the request contains reply text" do
    during = nil
    ask = lambda do |*, stream:|
      CHUNKS.each { stream.call(chunk(it)) }
      during = capture_turbo_stream_broadcasts(@draft)
      reply
    end

    write(ask)

    assert_equal [ "Writing the outline…" ], during.map { it.at("template strong").text }
    assert during.all? { it["action"] == "update" && it["target"] == "progress_family_study_draft_#{@draft.id}" }
    assert_equal "Checking scriptures, links and wording…", streamed("update").last.at("template strong").text
    assert_includes streamed("update").last.at("template").text, "Searched jw.org and wol.jw.org · 2 pages found"
    assert during.none? { it.to_html.include?("Talking to") || it.to_html.include?("Jehovah") }
  end

  test "a good draft replaces the panel once, with the checked result" do
    write(reply)

    assert_equal 1, streamed("replace").size
    assert_equal "ai_panel", streamed("replace").first["target"]
    assert_includes streamed("replace").first.to_html, "AI draft"
    assert_includes streamed("replace").first.to_html, "Talking to Jehovah as a family"
    assert_not_includes streamed("replace").first.to_html, "worries feel lighter"
  end

  test "after 10 drafts, discarding one still refuses an 11th" do
    9.times { family_study_draft(status: "drafted") }
    write(reply)
    @draft.discard

    draft = FamilyStudy::Draft.start(household: households(:home), user: users(:head), prompt: "Prayer as a family", length_minutes: 30, young_children: false)

    assert draft.errors.added?(:base, :limit)
  end

  test "discarded between the final write and the broadcast: no result broadcast" do
    reload = @draft.method(:reload)
    @draft.stub(:reload, -> { FamilyStudy::Draft.find(@draft.id).discard
                              reload.call }) do
      write(reply)
    end

    assert_predicate @draft, :discarded?
    assert_empty streamed("replace")
  end

  private
    # Runs write_now with moderation and the AI stubbed: +answer+ is the Ai::Reply, or a lambda standing in for
    # Chat#ask_within_purpose. No test calls a provider.
    def write(answer, flagged: false)
      ask = answer.is_a?(Proc) ? answer : ->(*, **) { answer }

      Ai::Moderation.stub(:flagged?, flagged) do
        @draft.chat.stub(:ask_within_purpose, ask) { @draft.write_now }
      end
    end

    def reply(**changes)
      parsed = {
        off_topic: false,
        title: "Talking to Jehovah as a family",
        opening: { scripture: "Philippians 4:6, 7", question: "What could we tell Jehovah about this week?" },
        points: [
          point("Jehovah listens to each of us", "Psalm 65:2", "Why does it matter that Jehovah hears even short prayers?"),
          point("Jehovah cares about our feelings", "Hezekiah 3:1", "How does it feel to know Jehovah cares?"),
          point("We can pray about anything", "1 Peter 5:7", "#{COPIED} What could we pray about together?")
        ],
        children: "",
        closing: "Choose one thing to thank Jehovah for each day this week."
      }.merge(changes).deep_stringify_keys

      Ai::Reply.new(Message.new(
        parsed: parsed,
        citations: [
          RubyLLM::Citation.new(url: PRAYING_TOGETHER, title: "Praying Together as a Family", cited_text: EXCERPT),
          RubyLLM::Citation.new(url: MADE_UP, title: "Made up", cited_text: "An excerpt from a page the search never returned.")
        ],
        web_sources: [ RubyLLM::WebSource.new(url: FAMILY_WORSHIP, title: "Family Worship"), RubyLLM::WebSource.new(url: PRAYING_TOGETHER, title: "Praying Together as a Family") ]
      ))
    end

    def point(heading, scripture, question)
      { heading: heading, scripture: scripture, question: question }
    end

    def chunk(content)
      RubyLLM::Chunk.new(role: :assistant, content: content)
    end

    def streamed(action)
      capture_turbo_stream_broadcasts(@draft).select { it["action"] == action }
    end
end
