require "test_helper"

class MeetingPart::DraftTest < ActiveSupport::TestCase
  # What Ai::Reply reads from RubyLLM's message: the parsed reply, its citations and the pages the search returned.
  Message = Data.define(:parsed, :citations, :web_sources)

  # The three pages the saved reply's search returned (test/fixtures/files/ai/meeting_part_outline.json).
  LESSON = "https://wol.jw.org/en/wol/d/r1/lp-e/1102023301".freeze
  ARTICLE = "https://www.jw.org/en/bible-teachings/questions/future-of-earth/".freeze
  QUESTIONS = "https://wol.jw.org/en/wol/d/r1/lp-e/1102016104".freeze
  SOURCES = [ { "url" => LESSON, "title" => "Love People brochure: lesson 1" }, { "url" => ARTICLE, "title" => "Article: the Bible’s promise for the earth" },
              { "url" => QUESTIONS, "title" => "Teaching brochure: using questions" } ].freeze
  REQUEST = "The person is busy and has a young family.".freeze

  setup do
    @part = meeting_parts(:head_conversation)
    @part.update!(preparation: "<p>My own words about the food drive.</p>", counsel: "Slow down at the start.")
    @draft = meeting_part_draft(@part, request: REQUEST)
  end

  test "a good outline ends drafted with its fields and sources" do
    write(saved_reply)

    assert_predicate @draft.reload, :drafted?
    result = @draft.result
    assert_equal "Leave the person curious about what the Bible promises for the earth.", result["aim"]
    assert_equal [ "A promise worth hearing", "Let them talk" ], result["points"].pluck("heading")
    assert_equal [ "Psalm 37:10, 11", "Proverbs 20:5" ], result["points"].pluck("scripture")
    assert_equal "Thank them, and agree on a day to come back.", result["close"]
    assert_equal "Read the lesson in the first link, then mark where in your opening you will apply it.", result["study_point"]
    assert_equal SOURCES, @draft.sources
    assert_not_includes @draft.sources.to_json, "Excerpt"
    assert Ai::Use.exists?(meeting_part_draft_id: @draft.id)
    assert_not_includes MeetingPart::Draft.connection.select_value(MeetingPart::Draft.where(id: @draft.id).select("result::text").to_sql), "curious"
  end

  test "the text sent holds the kind, minutes, setting, topic, study point, target words and request, and not the preparation, counsel, assistant, the person's name or the household's" do
    sent = moderated = nil
    write(->(text, **) { sent = text
                         saved_reply }, flagged: ->(text) { moderated = text
                                                             false })

    [ "Starting a Conversation", "3 minutes", "House to house", "Start a conversation about hope for the future, and offer to come back.",
      "lmd lesson 1 point 3", "312 words", REQUEST, "an outline" ].each { assert_includes sent, it }
    [ "food drive", "Slow down", "Ana Ortiz", "Hannah", "Head Family" ].each { assert_not_includes sent, it }
    assert_equal "Start a conversation about hope for the future, and offer to come back.\nlmd lesson 1 point 3\n#{REQUEST}", moderated
  end

  test "a part without a setting, study point or request sends none, and the study point advice is dropped" do
    sent = nil
    @part.update!(setting: nil, study_point: nil)
    @draft = meeting_part_draft(@part)

    write(->(text, **) { sent = text
                         saved_reply })

    assert_no_match(/Setting|Study point|Anything else/, sent)
    assert_nil @draft.reload.result["study_point"]
  end

  test "off topic ends off_topic and keeps its use" do
    write(saved_reply { it["off_topic"] = true })

    assert_predicate @draft.reload, :off_topic?
    assert_nil @draft.result
    assert Ai::Use.exists?(meeting_part_draft_id: @draft.id)
  end

  test "flagged by moderation doesn't count, and the AI is never called" do
    write(->(*, **) { flunk "the AI was called" }, flagged: true)

    assert_predicate @draft.reload, :flagged?
    assert_not Ai::Use.exists?(meeting_part_draft_id: @draft.id)
    assert_equal 15, users(:head).part_drafts_left_today
  end

  test "a provider error doesn't count" do
    write(->(*, **) { raise RubyLLM::OverloadedError, "Overloaded" })

    assert_predicate @draft.reload, :failed?
    assert_not Ai::Use.exists?(meeting_part_draft_id: @draft.id)
    assert_equal 15, users(:head).part_drafts_left_today
  end

  test "any other error fails the draft, deletes its use and is raised so it's seen" do
    assert_raises(NoMethodError) { write(->(*, **) { raise NoMethodError, "a bug" }) }

    assert_predicate @draft.reload, :failed?
    assert_not Ai::Use.exists?(meeting_part_draft_id: @draft.id)
  end

  test "a sentence quoting more than 5 words, or copying 8 words from a citation, is removed" do
    write(saved_reply do |parsed|
      parsed["outline"]["opening"] = "Smile and say hello. He said “the meek will possess the earth forever.” Ask what they think."
      parsed["outline"]["close"] = "Thank them. Excerpt one from the page, as the search returned it. Agree on a day to come back."
    end)

    assert_equal "Smile and say hello. Ask what they think.", @draft.reload.result["opening"]
    assert_equal "Thank them. Agree on a day to come back.", @draft.result["close"]
  end

  test "a point's scripture that isn't a reference (verse text) is dropped, and the point stays" do
    write(saved_reply { it["outline"]["points"][0]["scripture"] = "The wicked will be no more; the meek will possess the earth" })

    points = @draft.reload.result["points"]
    assert_equal [ "A promise worth hearing", "Let them talk" ], points.pluck("heading")
    assert_nil points.first["scripture"]
    assert_equal "Proverbs 20:5", points.last["scripture"]
  end

  test "a link on another host, or not in the search results, is dropped, and so is a web address in the text" do
    others = [ RubyLLM::Citation.new(url: "https://example.com/hope", title: "Elsewhere", cited_text: "Another site."),
               RubyLLM::Citation.new(url: "https://www.jw.org/en/an-article-the-search-never-returned/", title: "Made up", cited_text: "Never returned.") ]

    write(saved_reply(citations: others) { it["outline"]["points"][1]["explain"] = "Ask what stood out to them, as https://example.com/tips suggests." })

    assert_equal SOURCES, @draft.reload.sources
    assert_equal "Ask what stood out to them, as suggests.", @draft.result["points"].last["explain"]
  end

  test "fewer than an aim and one point ends failed and deletes the use" do
    write(saved_reply { it["outline"]["aim"] = "" })

    assert_predicate @draft.reload, :failed?
    assert_nil @draft.result
    assert_not Ai::Use.exists?(meeting_part_draft_id: @draft.id)

    @draft = meeting_part_draft(@part)
    write(saved_reply { |parsed| parsed["outline"]["points"] = [ { "heading" => "", "scripture" => "Psalm 37:10", "explain" => "" } ] })

    assert_predicate @draft.reload, :failed?
  end

  test "a draft stopped while the job runs stays stopped, keeps its use and counts toward the 15" do
    write(->(*, **) { MeetingPart::Draft.find(@draft.id).stop
                      saved_reply })

    assert_predicate @draft.reload, :stopped?
    assert_nil @draft.result
    assert Ai::Use.exists?(meeting_part_draft_id: @draft.id)
    assert_equal 14, users(:head).part_drafts_left_today
  end

  test "stopped mid-stream: the request ends there and the draft stays stopped" do
    streamed_to_the_end = false
    write(lambda do |*, stream:|
      stream.call(RubyLLM::Chunk.new(role: :assistant, content: '{"off_topic":false,'))
      MeetingPart::Draft.find(@draft.id).stop
      stream.call(RubyLLM::Chunk.new(role: :assistant, content: '"outline":'))
      streamed_to_the_end = true
      saved_reply
    end)

    assert_not streamed_to_the_end
    assert_predicate @draft.reload, :stopped?
  end

  test "a draft stopped before its job ran never reaches moderation or the AI" do
    @draft.stop

    write(->(*, **) { flunk "the AI was called" }, flagged: ->(*) { flunk "moderation was called" })

    assert_predicate @draft.reload, :stopped?
  end

  test "a provider error after Stop leaves the draft stopped with its use" do
    write(->(*, **) { MeetingPart::Draft.find(@draft.id).stop
                      raise RubyLLM::OverloadedError, "Overloaded" })

    assert_predicate @draft.reload, :stopped?
    assert Ai::Use.exists?(meeting_part_draft_id: @draft.id)
  end

  test "Stop on a draft already failed changes nothing" do
    write(->(*, **) { raise RubyLLM::OverloadedError, "Overloaded" })

    assert_not @draft.reload.stop
    assert_predicate @draft, :failed?
    assert_not Ai::Use.exists?(meeting_part_draft_id: @draft.id)
  end

  # Active Job rescues the queue's EnqueueError and perform_later returns false, so nothing raises.
  test "a job the queue refuses (perform_later false) ends the draft failed and deletes the use" do
    MeetingPart::WriteDraftJob.stub(:perform_later, false) { @draft.write_later }

    assert_predicate @draft.reload, :failed?
    assert_not Ai::Use.exists?(meeting_part_draft_id: @draft.id)
  end

  test "a job Solid Queue can't insert ends the draft failed and deletes the use" do
    refuse = ->(*) { raise SolidQueue::Job::EnqueueError, "ActiveRecord::ConnectionNotEstablished: queue database is down" }
    MeetingPart::WriteDraftJob.stub(:perform_later, refuse) { @draft.write_later }

    assert_predicate @draft.reload, :failed?
    assert_not Ai::Use.exists?(meeting_part_draft_id: @draft.id)
  end

  test "a good outline replaces the panel once, and nothing broadcast while drafting holds reply text" do
    during = nil
    write(lambda do |*, stream:|
      stream.call(RubyLLM::Chunk.new(role: :assistant, content: '{"off_topic":false,"outline":{"aim":"Leave the person curious'))
      during = capture_turbo_stream_broadcasts(@draft)
      saved_reply
    end)

    assert_equal [ "Writing the outline…" ], during.map { it.at("template strong").text }
    assert during.none? { it.to_html.include?("curious") }
    replaced = capture_turbo_stream_broadcasts(@draft).select { it["action"] == "replace" }
    assert_equal [ "ai_panel" ], replaced.pluck("target")
    assert_includes replaced.first.to_html, "Use this outline"
  end

  test "discard sets discarded once done, never while drafting, and never deletes" do
    drafted = meeting_part_draft(@part, status: "drafted")

    assert_no_difference -> { MeetingPart::Draft.count } do
      assert drafted.stop_or_discard
      assert @draft.stop_or_discard
    end
    assert_predicate drafted, :discarded?
    assert_predicate @draft, :stopped?
    assert_not meeting_part_draft(@part, status: "failed").discard
  end

  test "spoken_length counts the words of the outline that are said, not the aim or the study point advice" do
    draft = meeting_part_draft(@part, status: "drafted", result: { "aim" => "unsaid " * 130, "opening" => "one two three", "question" => "four five",
                                                                  "points" => [ { "heading" => "six", "explain" => "seven eight" } ], "close" => "nine ten", "study_point" => "unsaid " * 130 })

    assert_equal "About 10 s to say", draft.spoken_length.to_s
    assert_equal 10, draft.spoken_length.seconds
  end

  test "preparation_html is our own markup with every field escaped and references as plain text" do
    draft = meeting_part_draft(@part, status: "drafted", result: { "aim" => "<script>alert(1)</script>", "opening" => "Say hello.",
                                                                  "points" => [ { "heading" => "A promise", "scripture" => "Psalm 37:10, 11", "explain" => "It speaks of peace." } ],
                                                                  "question" => "", "close" => "Agree on a day.", "study_point" => "" })

    html = draft.preparation_html

    assert_includes html, "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert_not_includes html, "<script>"
    assert_includes html, "Read Psalm 37:10, 11."
    assert_includes html, "<strong>A promise</strong>"
    assert_not_includes html, "Question"
  end

  test "request and result are encrypted at rest" do
    raw = MeetingPart::Draft.connection.select_value(MeetingPart::Draft.where(id: @draft.id).select("request").to_sql)

    assert_equal REQUEST, @draft.reload.request
    assert_not_includes raw, "busy"
  end

  test "a 501-character request is invalid; 500 is fine" do
    @draft.request = "a" * 500
    assert_predicate @draft, :valid?

    @draft.request = "a" * 501
    assert_not @draft.valid?
  end

  test "the database refuses a kind of summary" do
    assert_raises(ActiveRecord::CheckViolation) { @draft.update_column(:kind, "summary") }
  end

  test "the database refuses a status of done" do
    assert_raises(ActiveRecord::CheckViolation) { @draft.update_column(:status, "done") }
  end

  test "the database refuses a draft without a part" do
    assert_raises(ActiveRecord::NotNullViolation) { MeetingPart::Draft.insert!(row(meeting_part_id: nil)) }
  end

  test "the database refuses a draft without a chat" do
    assert_raises(ActiveRecord::NotNullViolation) { MeetingPart::Draft.insert!(row(chat_id: nil)) }
  end

  test "the database refuses a draft without a person" do
    assert_raises(ActiveRecord::NotNullViolation) { MeetingPart::Draft.insert!(row(user_id: nil)) }
  end

  test "the database refuses a draft without a kind" do
    assert_raises(ActiveRecord::NotNullViolation) { MeetingPart::Draft.insert!(row(kind: nil)) }
  end

  test "the database refuses a draft without a status" do
    assert_raises(ActiveRecord::NotNullViolation) { MeetingPart::Draft.insert!(row(status: nil)) }
  end

  test "the database refuses a draft without sources" do
    assert_raises(ActiveRecord::NotNullViolation) { MeetingPart::Draft.insert!(row(sources: nil)) }
  end

  test "the database refuses a second draft on the same chat" do
    assert_raises(ActiveRecord::RecordNotUnique) { MeetingPart::Draft.insert!(row(chat_id: @draft.chat_id)) }
  end

  test "the database refuses a second use for the same draft" do
    assert_raises(ActiveRecord::RecordNotUnique) { Ai::Use.insert!({ user_id: users(:head).id, purpose: "meeting_part", meeting_part_draft_id: @draft.id }) }
  end

  private
    # Runs write_now with moderation and the AI stubbed: +answer+ is the Ai::Reply, or a lambda standing in for
    # Chat#ask_within_purpose; +flagged+ is moderation's answer, or a lambda for it. No test calls a provider.
    def write(answer, flagged: false)
      ask = answer.is_a?(Proc) ? answer : ->(*, **) { answer }

      Ai::Moderation.stub(:flagged?, flagged) do
        @draft.chat.stub(:ask_within_purpose, ask) { @draft.write_now }
      end
    end

    # The saved reply (test/fixtures/files/ai/meeting_part_outline.json) as Ai::Reply reads it, with any +citations+
    # added, after the block changes its parsed fields.
    def saved_reply(citations: [])
      body = JSON.parse(file_fixture("ai/meeting_part_outline.json").read)
      texts = body["content"].select { it["type"] == "text" }
      parsed = JSON.parse(texts.pluck("text").join).tap { yield it if block_given? }
      cited = texts.flat_map { it["citations"].to_a }.map { RubyLLM::Citation.new(url: it["url"], title: it["title"], cited_text: it["cited_text"]) }
      results = body["content"].select { it["type"] == "web_search_tool_result" }.flat_map { it["content"] }.map { RubyLLM::WebSource.new(url: it["url"], title: it["title"]) }

      Ai::Reply.new(Message.new(parsed:, citations: cited + citations, web_sources: results))
    end

    # A row for insert!, which skips validations, so the database alone decides.
    def row(**changes)
      { meeting_part_id: @part.id, chat_id: Chat.create!(user: users(:head), purpose: "meeting_part").id, user_id: users(:head).id,
        kind: "outline", status: "drafting", sources: [] }.merge(changes)
    end
end
