require "test_helper"

class PersonalStudy::AskTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  Message = Data.define(:parsed, :citations, :web_sources)

  setup do
    @head = users(:head)
    @head.accept_ai_terms(understood: true)
    @study = personal_studies(:head_suffering)
  end

  test "asking creates the question and its use, touches last_asked_at and enqueues the answer" do
    question = nil
    assert_difference [ -> { PersonalStudy::Question.count }, -> { Ai::Use.count } ], 1 do
      assert_enqueued_jobs(1, only: PersonalStudy::AnswerQuestionJob) { question = ask }
    end

    assert_predicate question, :asking?
    assert_equal @head, question.user
    assert_equal "personal_study", question.use.purpose
    assert_in_delta Time.current, @study.reload.last_asked_at, 1.second
  end

  test "the 31st question is refused" do
    use_today(30)

    question = nil
    assert_no_difference [ -> { PersonalStudy::Question.count }, -> { Ai::Use.count } ] do
      assert_no_enqueued_jobs { question = ask }
    end

    assert question.errors.added?(:base, :limit)
    assert_nil @study.reload.last_asked_at
  end

  test "the 30th is allowed" do
    use_today(29)

    assert_predicate ask, :persisted?
    assert_equal 0, @head.study_questions_left_today
  end

  test "midnight in the person's time zone resets it (travel)" do
    @head.update!(time_zone: "Auckland")
    auckland = ActiveSupport::TimeZone["Auckland"]

    travel_to auckland.local(2026, 11, 16, 23, 30) do
      use_today(30)
      assert ask.errors.added?(:base, :limit)
    end

    travel_to auckland.local(2026, 11, 17, 0, 5) do
      assert_predicate ask, :persisted?
    end
  end

  test "with no users.time_zone, the oldest active membership's household decides midnight, and asking from another household doesn't restart the count" do
    households(:home).update!(time_zone: "Pacific Time (US & Canada)")
    households(:parents).update!(time_zone: "Tokyo")
    memberships(:head_in_home).update_column(:created_at, 2.years.ago)
    memberships(:head_in_parents).update_column(:created_at, 1.year.ago)
    los_angeles = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]

    # 6am in Los Angeles is 11pm the day before in Tokyo.
    travel_to(los_angeles.local(2026, 11, 16, 6)) { use_today(30) }

    # 5:30pm in Los Angeles is past midnight in Tokyo and in UTC, but not yet in the oldest membership's household.
    travel_to los_angeles.local(2026, 11, 16, 17, 30) do
      Current.household = households(:parents)
      assert ask.errors.added?(:base, :limit)
    end

    travel_to los_angeles.local(2026, 11, 17, 0, 5) do
      assert_predicate ask, :persisted?
    end
  end

  test "with no time zone and no active membership, midnight is UTC's" do
    @head.memberships.update_all(active: false)

    assert_equal "UTC", @head.limit_time_zone
  end

  test "an off-topic reply with no paragraphs ends off_topic and still counts" do
    question = ask
    answer(question, off_topic: true, paragraphs: [])

    assert_predicate question.reload, :off_topic?
    assert_not_nil question.use
    assert_equal 29, @head.study_questions_left_today
  end

  test "a reply of paragraphs: [\"  \"] with no not_found ends failed, and its use is deleted" do
    question = ask
    answer(question, paragraphs: [ "  " ])

    assert_predicate question.reload, :failed?
    assert_nil question.use
    assert_equal 30, @head.study_questions_left_today
  end

  test "deleting a study with today's questions still refuses the 31st" do
    30.times { personal_study_question(@study) }

    @study.destroy!

    question = personal_studies(:head_daniel).ask("What is the stone in Daniel 2?", by: @head)
    assert question.errors.added?(:base, :limit)
    assert_equal 30, @head.ai_uses.where(question_id: nil).count
  end

  test "a child is :not_allowed" do
    child = users(:child)
    child.accept_ai_terms(understood: true)
    study = PersonalStudy.create!(user: child, title: "Noah's ark")

    question = nil
    assert_no_difference -> { Ai::Use.count } do
      question = study.ask("Why did Noah build an ark?", by: child, young_reader: true)
    end

    assert question.errors.added?(:base, :not_allowed)
    assert_not users(:child).may_ask_study_ai?
  end

  test "an adult may ask, and someone whose only membership has ended may not" do
    assert users(:spouse).may_ask_study_ai?
    assert_not users(:former).may_ask_study_ai?
  end

  test "without accepted terms it's :not_allowed" do
    @head.ai_acceptances.delete_all

    question = nil
    assert_no_difference -> { PersonalStudy::Question.count } do
      question = ask
    end

    assert question.errors.added?(:base, :not_allowed)
  end

  test "young_reader: true adds the young-reader line to the request" do
    sent = []
    capture = ->(text, **) { sent << text
                             reply }

    answer(ask, with: capture)
    answer(ask(young_reader: true), with: capture)

    assert_equal "Why does Jehovah allow suffering?", sent.first
    assert_equal "Why does Jehovah allow suffering?\n\nThe reader is young: write simply, for a young reader.", sent.last
  end

  private
    def ask(young_reader: false)
      @study.ask("Why does Jehovah allow suffering?", by: @head, young_reader: young_reader)
    end

    # Uses with no question, as a deleted study leaves them.
    def use_today(count)
      count.times { Ai::Use.create!(user: @head, purpose: "personal_study") }
    end

    def answer(question, with: nil, **changes)
      Ai::Moderation.stub(:flagged?, false) do
        question.personal_study.chat.stub(:ask_within_purpose, with || ->(*, **) { reply(**changes) }) { question.answer_now }
      end
    end

    def reply(**changes)
      parsed = { off_topic: false, not_found: false, not_found_note: "", paragraphs: [ "Jehovah never causes suffering. Read James 1:13." ], next_questions: [] }
      Ai::Reply.new(Message.new(parsed: parsed.merge(changes).deep_stringify_keys, citations: [], web_sources: []))
    end
end
