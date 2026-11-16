require "test_helper"

class PersonalStudy::QuestionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # What Ai::Reply reads from RubyLLM's message: the parsed reply, its citations and the pages the search returned.
  Message = Data.define(:parsed, :citations, :web_sources)

  SUFFERING = "https://www.jw.org/en/bible-teachings/questions/why-does-god-allow-suffering/".freeze
  END_OF_SUFFERING = "https://wol.jw.org/en/wol/d/r1/lp-e/1102008083".freeze
  MADE_UP = "https://www.jw.org/en/bible-teachings/questions/an-article-the-search-never-returned/".freeze
  EXCERPT = "Jehovah has allowed suffering for a time so that the issues raised in Eden would be settled once and for all.".freeze
  COPIED = "Jehovah has allowed suffering for a time so that the issues raised in Eden would be settled.".freeze
  NOT_FOUND = "I couldn't find jw.org or wol.jw.org pages that answer this.".freeze
  CHUNKS = [ '{"off_topic":false,"paragraphs":["Jehovah ', 'never causes suffering"' ].freeze

  setup do
    @question = personal_study_question
  end

  test "good answer stored with sources" do
    answer(reply)

    assert_predicate @question.reload, :answered?
    assert_equal [ "Jehovah never causes suffering. Read James 1:13.", "He will soon end it for good, as Revelation 21:4 promises." ], @question.answer["paragraphs"]
    assert_equal [ "Why did Jehovah let the issue be settled over time?" ], @question.answer["next_questions"]
    assert_equal false, @question.answer["not_found"]
    assert_equal [ { "url" => SUFFERING, "title" => "Why Does God Allow Suffering?" }, { "url" => END_OF_SUFFERING, "title" => "The End of Suffering" } ], @question.sources
    assert_not_includes @question.sources.to_json, EXCERPT
    assert_not_includes PersonalStudy::Question.connection.select_value(PersonalStudy::Question.where(id: @question.id).select("answer::text").to_sql), "Jehovah"
    assert_not_nil @question.use
  end

  test "not found stored" do
    answer(reply(not_found: true, not_found_note: NOT_FOUND, paragraphs: [], next_questions: []))

    assert_predicate @question.reload, :answered?
    assert_equal true, @question.answer["not_found"]
    assert_equal NOT_FOUND, @question.answer["not_found_note"]
    assert_empty @question.answer["paragraphs"]
  end

  test "off topic" do
    answer(reply(off_topic: true, paragraphs: [], next_questions: []))

    assert_predicate @question.reload, :off_topic?
    assert_nil @question.answer
    assert_empty @question.sources
    assert_not_nil @question.use
  end

  test "flagged (no AI call, use removed)" do
    assert_difference -> { Ai::Use.count }, -1 do
      answer(->(*, **) { flunk "the AI was called" }, flagged: true)
    end

    assert_predicate @question.reload, :flagged?
    assert_nil @question.use
  end

  test "failed (use removed)" do
    assert_difference -> { Ai::Use.count }, -1 do
      answer(->(*, **) { raise RubyLLM::OverloadedError, "Overloaded" })
    end

    assert_predicate @question.reload, :failed?
    assert_nil @question.answer
    assert_nil @question.use
  end

  test "a reply that isn't a JSON object: failed" do
    answer(->(*, **) { raise Ai::Reply::Malformed, "The reply isn't a JSON object" })

    assert_predicate @question.reload, :failed?
  end

  test "any other error: failed, and raised so it's seen" do
    assert_raises(NoMethodError) { answer(->(*, **) { raise NoMethodError, "a bug" }) }

    assert_predicate @question.reload, :failed?
  end

  test "a question stopped before its job ran never reaches moderation or the AI" do
    @question.stop

    Ai::Moderation.stub(:flagged?, ->(*) { flunk "moderation was called" }) do
      @question.personal_study.chat.stub(:ask_within_purpose, ->(*, **) { flunk "the AI was called" }) { @question.answer_now }
    end

    assert_predicate @question.reload, :stopped?
    assert_not_nil @question.use
  end

  test "stopped mid-stream: stays stopped, with no answer" do
    streamed_to_the_end = false
    ask = lambda do |*, stream:|
      stream.call(chunk(CHUNKS.first))
      PersonalStudy::Question.find(@question.id).stop
      stream.call(chunk(CHUNKS.last))
      streamed_to_the_end = true
      reply
    end

    answer(ask)

    assert_not streamed_to_the_end
    assert_predicate @question.reload, :stopped?
    assert_nil @question.answer
  end

  test "stopped before the final write stays stopped with no broadcast" do
    answer(->(*, **) { PersonalStudy::Question.find(@question.id).stop
                       reply })

    assert_predicate @question.reload, :stopped?
    assert_nil @question.answer
    assert_empty streamed("replace")
  end

  test "stopping only stops a question still asking" do
    assert @question.stop
    assert_predicate @question, :stopped?

    answered = personal_study_question(status: "answered")
    assert_not answered.stop
    assert_predicate answered, :answered?
  end

  test "copied text removed" do
    answer(reply(paragraphs: [ "#{COPIED} He will soon end it for good, as Revelation 21:4 promises." ]))

    assert_predicate @question.reload, :answered?
    assert_equal [ "He will soon end it for good, as Revelation 21:4 promises." ], @question.answer["paragraphs"]
  end

  test "every paragraph removed by the checks: failed and its use deleted" do
    assert_difference -> { Ai::Use.count }, -1 do
      answer(reply(paragraphs: [ COPIED, "“Jehovah has allowed suffering for a time,” as one page says." ]))
    end

    assert_predicate @question.reload, :failed?
    assert_nil @question.answer
  end

  test "a not_found note with no paragraphs: answered" do
    answer(reply(not_found: true, not_found_note: NOT_FOUND, paragraphs: [ COPIED ]))

    assert_predicate @question.reload, :answered?
    assert_empty @question.answer["paragraphs"]
    assert_equal NOT_FOUND, @question.answer["not_found_note"]
  end

  test "a failed question deletes only its own use, not another use from the same day" do
    other = personal_study_question(personal_studies(:head_daniel))
    orphan = Ai::Use.create!(user: users(:head), purpose: "personal_study")

    answer(->(*, **) { raise RubyLLM::OverloadedError, "Overloaded" })

    assert_nil @question.reload.use
    assert_not_nil other.reload.use
    assert Ai::Use.exists?(orphan.id)
  end

  test "a link not in the search results dropped" do
    answer(reply(paragraphs: [ "Jehovah never causes suffering, as #{MADE_UP} explains. Read James 1:13." ]))

    assert_not_includes @question.reload.sources.pluck("url"), MADE_UP
    assert_equal [ "Jehovah never causes suffering, as explains. Read James 1:13." ], @question.answer["paragraphs"]
  end

  test "no progress broadcast contains answer text" do
    during = nil
    ask = lambda do |*, stream:|
      CHUNKS.each { stream.call(chunk(it)) }
      during = capture_turbo_stream_broadcasts(@question)
      reply
    end

    answer(ask)

    assert_equal [ "Writing the answer…" ], during.map { it.at("template strong").text }
    assert during.all? { it["action"] == "update" && it["target"] == "progress_personal_study_question_#{@question.id}" }
    assert_equal "Checking scriptures, links and wording…", streamed("update").last.at("template strong").text
    assert streamed("update").none? { it.to_html.include?("suffering") }
  end

  # The study's counts and sources first, as the page stops listening once the question it listens on is replaced.
  test "a good answer replaces the study's counts and sources, then the question once, with the checked result" do
    study = @question.personal_study
    answer(reply(paragraphs: [ "#{COPIED} Jehovah never causes suffering. Read James 1:13." ]))

    assert_equal [ "counts_personal_study_#{study.id}", "sources_personal_study_#{study.id}", "personal_study_question_#{@question.id}" ],
      streamed("replace").map { it["target"] }
    assert_includes streamed("replace").first.to_html, "1 question · 2 pages linked"
    assert_includes streamed("replace").second.to_html, "The End of Suffering"
    assert_includes streamed("replace").last.to_html, "Jehovah never causes suffering."
    assert streamed("replace").none? { it.to_html.include?("issues raised in Eden") }
  end

  test "a refused answer replaces only the question" do
    answer(reply(off_topic: true, paragraphs: [], next_questions: []))

    assert_equal [ "personal_study_question_#{@question.id}" ], streamed("replace").map { it["target"] }
    assert_includes streamed("replace").sole.to_html, "That's outside what personal study answers."
  end

  test "the job takes an id and calls answer_now" do
    assert_enqueued_with(job: PersonalStudy::AnswerQuestionJob, args: [ @question.id ]) { @question.answer_later }

    Ai::Moderation.stub(:flagged?, true) { perform_enqueued_jobs }
    assert_predicate @question.reload, :flagged?
  end

  # Active Job rescues the queue's EnqueueError and perform_later returns false, so nothing raises.
  test "answer_later fails the question and gives back its use when the queue refuses its job" do
    PersonalStudy::AnswerQuestionJob.stub(:perform_later, false) { @question.answer_later }

    assert_predicate @question.reload, :failed?
    assert_nil @question.use
  end

  test "answer_later fails the question when Solid Queue can't insert its job" do
    refuse = ->(*) { raise SolidQueue::Job::EnqueueError, "ActiveRecord::ConnectionNotEstablished: queue database is down" }
    PersonalStudy::AnswerQuestionJob.stub(:perform_later, refuse) { @question.answer_later }

    assert_predicate @question.reload, :failed?
    assert_nil @question.use
  end

  test "a 1,001-character prompt is invalid; 1,000 is fine" do
    @question.prompt = "a" * 1_000
    assert_predicate @question, :valid?

    @question.prompt = "a" * 1_001
    assert_not @question.valid?
    assert_equal [ "is too long (maximum is 1000 characters)" ], @question.errors[:prompt]
  end

  test "the prompt is encrypted at rest" do
    assert_not_includes PersonalStudy::Question.connection.select_value(PersonalStudy::Question.where(id: @question.id).select(:prompt).to_sql), "suffering"
  end

  test "deleting the study deletes its questions and keeps their uses, still counting" do
    use = @question.use

    personal_studies(:head_suffering).destroy!

    assert_not PersonalStudy::Question.exists?(@question.id)
    assert_nil use.reload.question_id
  end

  test "save_to_notes appends the text and links" do
    study = @question.personal_study
    study.update!(notes: "<p>My own thoughts first.</p>")
    saved_answer

    @question.save_to_notes

    notes = study.reload.notes.body
    assert_equal [ "My own thoughts first.", "Jehovah never causes suffering.", "He will soon end it for good.", "Pages:" ],
      notes.fragment.find_all("p").map { it.text.squish }
    assert_equal [ [ SUFFERING, "Why Does God Allow Suffering?" ], [ END_OF_SUFFERING, "The End of Suffering" ] ],
      notes.fragment.find_all("li a").map { [ it["href"], it.text ] }
    assert_operator notes.to_html.index("My own thoughts first."), :<, notes.to_html.index("Jehovah never causes suffering.")
  end

  test "references become scripture links after save" do
    saved_answer(paragraphs: [ "Jehovah never causes suffering. Read James 1:13." ])

    @question.save_to_notes

    assert_equal [ Bible::Reference.find("59:1:13") ], @question.personal_study.reload.notes.body.attachables
  end

  test "escapes <script>" do
    saved_answer(paragraphs: [ %(<script>alert("hi")</script> Read James 1:13.) ],
      sources: [ { "url" => SUFFERING, "title" => "<script>alert(1)</script>" } ])

    @question.save_to_notes

    notes = @question.personal_study.reload.notes.body
    assert_empty notes.fragment.find_all("script")
    assert_includes notes.to_plain_text, %(<script>alert("hi")</script>)
    assert_includes notes.to_plain_text, "<script>alert(1)</script>"
  end

  test "a stopped question raises" do
    @question.update!(status: "stopped")

    assert_raises(PersonalStudy::Question::NotAnswered) { @question.save_to_notes }
    assert_nil @question.personal_study.reload.notes
  end

  test "database: a status of done raises CheckViolation" do
    assert_raises(ActiveRecord::CheckViolation) { @question.update_column(:status, "done") }
  end

  test "database: a question needs a prompt" do
    assert_raises(ActiveRecord::NotNullViolation) { @question.update_column(:prompt, nil) }
  end

  test "database: a question needs a person" do
    assert_raises(ActiveRecord::NotNullViolation) { @question.update_column(:user_id, nil) }
  end

  private
    # Runs answer_now with moderation and the AI stubbed: +answer+ is the Ai::Reply, or a lambda standing in for
    # Chat#ask_within_purpose. No test calls a provider.
    def answer(answer, flagged: false)
      ask = answer.is_a?(Proc) ? answer : ->(*, **) { answer }

      Ai::Moderation.stub(:flagged?, flagged) do
        @question.personal_study.chat.stub(:ask_within_purpose, ask) { @question.answer_now }
      end
    end

    def reply(**changes)
      parsed = {
        off_topic: false,
        not_found: false,
        not_found_note: "",
        paragraphs: [ "Jehovah never causes suffering. Read James 1:13.", "  ", "He will soon end it for good, as Revelation 21:4 promises." ],
        next_questions: [ "Why did Jehovah let the issue be settled over time?" ]
      }.merge(changes).deep_stringify_keys

      Ai::Reply.new(Message.new(
        parsed: parsed,
        citations: [
          RubyLLM::Citation.new(url: END_OF_SUFFERING, title: "The End of Suffering", cited_text: EXCERPT),
          RubyLLM::Citation.new(url: MADE_UP, title: "Made up", cited_text: "An excerpt from a page the search never returned.")
        ],
        web_sources: [ RubyLLM::WebSource.new(url: SUFFERING, title: "Why Does God Allow Suffering?"), RubyLLM::WebSource.new(url: END_OF_SUFFERING, title: "The End of Suffering") ]
      ))
    end

    # An answered question, as the job leaves it, with both pages.
    def saved_answer(paragraphs: [ "Jehovah never causes suffering.", "He will soon end it for good." ], sources: nil)
      @question.update!(status: "answered", answer: { "not_found" => false, "not_found_note" => "", "paragraphs" => paragraphs, "next_questions" => [] },
        sources: sources || [ { "url" => SUFFERING, "title" => "Why Does God Allow Suffering?" }, { "url" => END_OF_SUFFERING, "title" => "The End of Suffering" } ])
    end

    def chunk(content)
      RubyLLM::Chunk.new(role: :assistant, content: content)
    end

    def streamed(action)
      capture_turbo_stream_broadcasts(@question).select { it["action"] == action }
    end
end
