require "test_helper"

# One AI writing of a daily brief and its checks (docs/design/daily-brief.md, The reply and How a writing runs). Tuesday
# 17 November 2026, Hannah's brief from the husband-and-father starter. No test calls a provider: the AI and moderation
# are stubbed, with the saved reply in test/fixtures/files/ai/daily_brief.json.
class DailyBrief::WritingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  Message = Data.define(:parsed, :citations, :web_sources)

  DAILY_TEXT = "https://wol.jw.org/en/wol/dt/r1/lp-e/2026/11/17".freeze
  SOURCES = [ { "url" => DAILY_TEXT, "title" => "Today's text and comment" },
              { "url" => "https://wol.jw.org/en/wol/d/r1/lp-e/1200002787", "title" => "Insight: Long-Suffering" },
              { "url" => "https://www.jw.org/en/library/books/imitate-their-faith/abraham/", "title" => "Imitate Their Faith: Abraham" } ].freeze

  setup do
    @user = users(:head)
    @user.update!(time_zone: "Central Time (US & Canada)")
    @user.accept_ai_terms(understood: "1")
    travel_to Time.utc(2026, 11, 17, 15)
    @plan = travel_to(3.days.ago) { DailyBrief::Plan.start(@user, starter: "husband_and_father") }
    @brief = DailyBrief.for(@user)
    @writing = daily_brief_writing(@brief)
  end

  test "written: the fields are saved and the sources that passed Ai::SourceLink" do
    others = [ RubyLLM::Citation.new(url: "https://example.com/patience", title: "Elsewhere", cited_text: "Another site."),
               RubyLLM::Citation.new(url: "https://www.jw.org/en/never-returned/", title: "Made up", cited_text: "Never returned.") ]
    write(saved_reply(citations: others))

    assert_predicate @writing.reload, :written?
    result = @writing.result
    assert_equal "Patience is letting Jehovah's timing be Jehovah's timing, instead of pushing for a faster, easier one of my own.", result["thread"]
    assert_equal "Acts 10:28", result.dig("daily_text", "reference")
    assert_equal "Acts 10:29", result.dig("daily_text", "apply_scripture")
    assert_equal "Matthew 16:21-23", result.dig("reading", "passage")
    assert_equal [ "Matthew 16:21", "Matthew 16:22", "Matthew 16:23" ], result.dig("reading", "look_for").pluck("verses")
    assert_equal "Patience", result.dig("quality", "name")
    assert_equal "Galatians 5:22, 23", result.dig("quality", "what_scripture")
    assert_equal "2 Peter 3:9", result.dig("appreciation", "scripture")
    assert_equal [ "Ephesians 5:25", "Deuteronomy 6:6, 7", "1 Timothy 3:8" ], result["focus"].pluck("scripture")
    assert_equal [ "Genesis 21:5; Hebrews 6:15", "Acts 7:23-30; Hebrews 11:27" ], result.dig("faith", "examples").pluck("scriptures")
    assert_equal "Have you ever really wanted something right now, and had to wait?", result.dig("children", "ask")
    assert_equal 4, result["evening"].size
    assert_equal SOURCES, @writing.sources
    assert_not_includes @writing.sources.to_json, "Excerpt"
    assert Ai::Use.exists?(daily_brief_writing_id: @writing.id)
    assert_not_includes DailyBrief::Writing.connection.select_value(DailyBrief::Writing.where(id: @writing.id).select("result::text").to_sql), "Patience"
  end

  test "the text sent is the purpose's, and moderation reads what the person typed" do
    sent = moderated = nil
    write(->(text, **) { sent = text
                         saved_reply }, flagged: ->(text) { moderated = text
                                                             false })

    purpose = Ai::Purpose.find("daily_brief")
    assert_equal purpose.sent_text(@brief), sent
    assert_equal purpose.typed_text(@brief), moderated
  end

  test "off topic ends off_topic and keeps its use" do
    write(saved_reply { it["off_topic"] = true })

    assert_predicate @writing.reload, :off_topic?
    assert_nil @writing.result
    assert Ai::Use.exists?(daily_brief_writing_id: @writing.id)
  end

  test "flagged by moderation ends flagged, deletes the use and never calls the AI" do
    write(->(*, **) { flunk "the AI was called" }, flagged: true)

    assert_predicate @writing.reload, :flagged?
    assert_not Ai::Use.exists?(daily_brief_writing_id: @writing.id)
    assert_equal 3, @user.daily_brief_writings_left_today
  end

  test "a provider error ends failed and deletes the use" do
    write(->(*, **) { raise RubyLLM::OverloadedError, "Overloaded" })

    assert_predicate @writing.reload, :failed?
    assert_not Ai::Use.exists?(daily_brief_writing_id: @writing.id)
  end

  test "any other error fails the writing, deletes its use and is raised so it's seen" do
    assert_raises(NoMethodError) { write(->(*, **) { raise NoMethodError, "a bug" }) }

    assert_predicate @writing.reload, :failed?
    assert_not Ai::Use.exists?(daily_brief_writing_id: @writing.id)
  end

  test "a sentence quoting more than 5 words, or copying 8 words from a citation, is removed" do
    write(saved_reply do |parsed|
      parsed["quality"]["what"] = "More than waiting. He wrote “love is patient and kind, love is not jealous.” Keep hoping."
      parsed["appreciation"]["seen"] = "He waits. Excerpt one from the page, as the search returned it. He waited for Peter."
    end)

    assert_equal "More than waiting. Keep hoping.", @writing.reload.result.dig("quality", "what")
    assert_equal "He waits. He waited for Peter.", @writing.result.dig("appreciation", "seen")
  end

  test "a reference that doesn't parse is dropped and its section stays" do
    write(saved_reply do |parsed|
      parsed["quality"]["what_scripture"] = "Love is patient and kind"
      parsed["faith"]["examples"][0]["scriptures"] = "Genesis 21:5; Hebrews 99:1"
    end)

    quality = @writing.reload.result["quality"]
    assert_nil quality["what_scripture"]
    assert_equal "More than waiting. A decision to hold back and keep hoping when I could push.", quality["what"]
    assert_equal "Luke 22:24-27", quality["jesus_scripture"]
    assert_equal "Genesis 21:5", @writing.result.dig("faith", "examples", 0, "scriptures")
  end

  test "the daily text is kept when the day's page is among the sources" do
    write(saved_reply)

    assert_equal "Peter is in the home of Cornelius, a man of the nations. He explains that God has shown him to change how he looks at people.",
                 @writing.reload.result.dig("daily_text", "happening")
  end

  test "the daily text is dropped when the day's page isn't among the sources" do
    write(saved_reply(web_sources: ->(results) { results.reject { it.url == DAILY_TEXT } }))

    assert_predicate @writing.reload, :written?
    assert_nil @writing.result["daily_text"]
    assert_not_includes @writing.sources.pluck("url"), DAILY_TEXT
  end

  test "another day's text among the sources doesn't keep the daily text" do
    other_day = RubyLLM::WebSource.new(url: "https://wol.jw.org/en/wol/dt/r1/lp-e/2026/11/16", title: "Yesterday's text")
    write(saved_reply(web_sources: ->(results) { results.reject { it.url == DAILY_TEXT } + [ other_day ] }))

    assert_nil @writing.reload.result["daily_text"]
  end

  test "a section that's off in the plan is ignored" do
    @plan.update!(sections: %w[ daily_text reading ])
    @brief.destroy!
    @brief = DailyBrief.for(@user)
    @writing = daily_brief_writing(@brief)

    write(saved_reply)

    result = @writing.reload.result
    assert_predicate @writing, :written?
    assert_nil result["faith"]
    assert_nil result["children"]
    assert_nil result["evening"]
    assert result["reading"]
    assert result["quality"], "a focus area's section isn't one of the five"
  end

  test "focus rows beyond the plan's role focus areas are ignored" do
    write(saved_reply { it["focus"] << { "action" => "One more.", "scripture" => "" } })

    assert_equal 3, @writing.reload.result["focus"].size
  end

  test "a string over 300 characters is dropped, and the fields beside it stay" do
    write(saved_reply { it["quality"]["jesus"] = "a" * 301 })

    quality = @writing.reload.result["quality"]
    assert_nil quality["jesus"]
    assert_equal "Patience", quality["name"]
  end

  test "a thread over 200 characters is dropped, so the writing fails; 200 is fine" do
    write(saved_reply { it["thread"] = "a" * 201 })
    assert_predicate @writing.reload, :failed?

    @writing = daily_brief_writing(@brief)
    write(saved_reply { it["thread"] = "a" * 200 })
    assert_equal "a" * 200, @writing.reload.result["thread"]
  end

  test "less than the thread and two sections ends failed and deletes the use" do
    write(saved_reply { |parsed| %w[ daily_text reading quality appreciation focus ].each { parsed.delete(it) } })

    assert_predicate @writing.reload, :failed?
    assert_nil @writing.result
    assert_not Ai::Use.exists?(daily_brief_writing_id: @writing.id)
  end

  test "no thread ends failed" do
    write(saved_reply { it["thread"] = "" })

    assert_predicate @writing.reload, :failed?
  end

  test "the thread and two sections are enough" do
    write(saved_reply { |parsed| %w[ daily_text reading quality appreciation ].each { parsed.delete(it) } })

    assert_predicate @writing.reload, :written?
    assert_equal %w[ thread focus faith children evening ], @writing.result.keys
  end

  test "a provider error after Stop leaves it stopped with its use" do
    write(->(*, **) { @writing.stop
                      raise RubyLLM::OverloadedError, "Overloaded" })

    assert_predicate @writing.reload, :stopped?
    assert Ai::Use.exists?(daily_brief_writing_id: @writing.id)
  end

  test "a reply after Stop isn't saved" do
    write(->(*, **) { @writing.stop
                      saved_reply })

    assert_predicate @writing.reload, :stopped?
    assert_nil @writing.result
  end

  test "a writing already finished isn't written again" do
    @writing.update!(status: "written", result: { "thread" => "Kept." })

    write(->(*, **) { flunk "the AI was called" }, flagged: ->(*) { flunk "moderation was called" })

    assert_equal({ "thread" => "Kept." }, @writing.reload.result)
  end

  test "write_later queues the job with the writing's id" do
    assert_enqueued_with(job: DailyBrief::WriteJob, args: [ @writing.id ]) { @writing.write_later }
  end

  test "a job the queue refused ends the writing failed and gives its use back" do
    DailyBrief::WriteJob.stub(:perform_later, false) { @writing.write_later }

    assert_predicate @writing.reload, :failed?
    assert_not Ai::Use.exists?(daily_brief_writing_id: @writing.id)
  end

  test "a job Solid Queue refused ends the writing failed and is reported" do
    DailyBrief::WriteJob.stub(:perform_later, ->(*) { raise SolidQueue::Job::EnqueueError, "full" }) do
      assert_error_reported(SolidQueue::Job::EnqueueError) { @writing.write_later }
    end

    assert_predicate @writing.reload, :failed?
  end

  test "any other error queueing the job ends the writing failed, gives its use back and is raised" do
    DailyBrief::WriteJob.stub(:perform_later, ->(*) { raise ArgumentError, "unexpected" }) do
      assert_raises(ArgumentError) { @writing.write_later }
    end

    assert_predicate @writing.reload, :failed?
    assert_not Ai::Use.exists?(daily_brief_writing_id: @writing.id)
  end

  test "the writing and its chat go with the brief, and its use stays" do
    use = @writing.use

    @brief.destroy!

    assert_not DailyBrief::Writing.exists?(@writing.id)
    assert_not Chat.exists?(@writing.chat_id)
    assert_nil use.reload.daily_brief_writing_id
  end

  test "the database deletes the writing with its chat" do
    Chat.where(id: @writing.chat_id).delete_all

    assert_not DailyBrief::Writing.exists?(@writing.id)
  end

  test "the database refuses a status it doesn't know" do
    assert_raises(ActiveRecord::StatementInvalid) { DailyBrief::Writing.insert!(row(status: "drafted")) }
  end

  test "the database refuses a second writing on one chat" do
    assert_raises(ActiveRecord::RecordNotUnique) { DailyBrief::Writing.insert!(row(chat_id: @writing.chat_id)) }
  end

  test "the database refuses a writing with no brief" do
    assert_raises(ActiveRecord::NotNullViolation) { DailyBrief::Writing.insert!(row(daily_brief_id: nil)) }
  end

  test "the database refuses a second use for one writing" do
    assert_raises(ActiveRecord::RecordNotUnique) { Ai::Use.insert!({ user_id: @user.id, purpose: "daily_brief", daily_brief_writing_id: @writing.id }) }
  end

  private
    # Runs write_now with moderation and the AI stubbed: +answer+ is the Ai::Reply, or a lambda standing in for
    # Chat#ask_within_purpose; +flagged+ is moderation's answer, or a lambda for it.
    def write(answer, flagged: false)
      ask = answer.is_a?(Proc) ? answer : ->(*, **) { answer }

      Ai::Moderation.stub(:flagged?, flagged) do
        @writing.chat.stub(:ask_within_purpose, ask) { @writing.write_now }
      end
    end

    # The saved reply as Ai::Reply reads it, with any +citations+ added and +web_sources+ changing the search results,
    # after the block changes its parsed fields.
    def saved_reply(citations: [], web_sources: :itself.to_proc)
      body = JSON.parse(file_fixture("ai/daily_brief.json").read)
      texts = body["content"].select { it["type"] == "text" }
      parsed = JSON.parse(texts.pluck("text").join).tap { yield it if block_given? }
      cited = texts.flat_map { it["citations"].to_a }.map { RubyLLM::Citation.new(url: it["url"], title: it["title"], cited_text: it["cited_text"]) }
      results = body["content"].select { it["type"] == "web_search_tool_result" }.flat_map { it["content"] }.map { RubyLLM::WebSource.new(url: it["url"], title: it["title"]) }

      Ai::Reply.new(Message.new(parsed:, citations: cited.select { web_sources.(results).map(&:url).include?(it.url) } + citations,
                                web_sources: web_sources.(results)))
    end

    def row(**changes)
      { daily_brief_id: @brief.id, chat_id: Chat.create!(user: @user, purpose: "daily_brief").id, status: "writing", sources: [] }.merge(changes)
    end
end
