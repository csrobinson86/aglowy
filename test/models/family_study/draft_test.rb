require "test_helper"

class FamilyStudy::DraftTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @household = households(:home)
  end

  test "the database refuses a length_minutes of 20" do
    draft = family_study_draft

    assert_raises(ActiveRecord::CheckViolation) { draft.update_column(:length_minutes, 20) }
  end

  test "the database refuses a status of done" do
    draft = family_study_draft

    assert_raises(ActiveRecord::CheckViolation) { draft.update_column(:status, "done") }
  end

  test "the database refuses a second draft on the same chat" do
    draft = family_study_draft
    other = family_study_draft

    assert_raises(ActiveRecord::RecordNotUnique) { other.update_column(:chat_id, draft.chat_id) }
  end

  test "a 501-character prompt is invalid; 500 is fine" do
    draft = family_study_draft

    draft.prompt = "a" * 500
    assert_predicate draft, :valid?

    draft.prompt = "a" * 501
    assert_not draft.valid?
    assert_equal [ "is too long (maximum is 500 characters)" ], draft.errors[:prompt]
  end

  test "a length other than 30, 45 or 60 minutes is invalid" do
    draft = family_study_draft

    draft.length_minutes = 20
    assert_not draft.valid?
    assert_equal [ "is not included in the list" ], draft.errors[:length_minutes]
  end

  test "prompt and outline are encrypted at rest" do
    draft = family_study_draft(prompt: "Prayer as a family", outline: { "title" => "Talking to Jehovah together" })
    raw = FamilyStudy::Draft.connection.select_one(FamilyStudy::Draft.where(id: draft.id).select("prompt", "outline::text AS outline").to_sql)

    assert_equal "Prayer as a family", draft.reload.prompt
    assert_equal "Talking to Jehovah together", draft.outline["title"]
    assert_not_includes raw["prompt"], "Prayer"
    assert_not_includes raw["outline"], "Jehovah"
  end

  test "counted_today counts drafting, drafted, off_topic, stopped and discarded, not failed or flagged" do
    statuses = %w[ drafting drafted off_topic flagged failed stopped discarded ]
    statuses.each { family_study_draft(status: it) }
    family_study_draft(household: households(:other), user: users(:outsider))

    assert_equal %w[ discarded drafted drafting off_topic stopped ], @household.family_study_drafts.counted_today.pluck(:status).sort
  end

  test "counted_today resets at midnight in the household's time zone" do
    @household.update!(time_zone: "Pacific Time (US & Canada)")
    zone = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]

    travel_to zone.local(2026, 11, 16, 23, 59)
    family_study_draft
    assert_equal 1, @household.family_study_drafts.counted_today.count

    # 8:01 am UTC: already the 17th in UTC, still the 16th until now in California.
    travel_to zone.local(2026, 11, 17, 0, 1)
    assert_equal 0, @household.family_study_drafts.counted_today.count

    family_study_draft
    assert_equal 1, @household.family_study_drafts.counted_today.count
  end

  test "start creates the chat and a drafting draft, and writes it later" do
    draft = nil

    assert_enqueued_with(job: FamilyStudy::WriteDraftJob) do
      draft = start
    end

    assert_predicate draft, :persisted?
    assert_predicate draft, :drafting?
    assert_equal [ draft.id ], enqueued_jobs.last["arguments"]
    assert_equal [ "family_study_draft", users(:head), @household ], [ draft.chat.purpose, draft.chat.user, draft.chat.household ]
    assert_equal [ users(:head), "Prayer as a family", 45, true ], [ draft.user, draft.prompt, draft.length_minutes, draft.young_children ]
  end

  # Active Job rescues the queue's EnqueueError and perform_later returns false, so nothing raises.
  test "start marks the draft failed when the queue refuses its job, so it doesn't use one of the day's drafts" do
    draft = FamilyStudy::WriteDraftJob.stub(:perform_later, false) { start }

    assert_predicate draft, :failed?
    assert_predicate draft.reload, :failed?
    assert_equal 0, @household.family_study_drafts.counted_today.count
  end

  test "start marks the draft failed when Solid Queue can't insert its job, so it doesn't use one of the day's drafts" do
    refuse = ->(*) { raise SolidQueue::Job::EnqueueError, "ActiveRecord::ConnectionNotEstablished: queue database is down" }
    draft = FamilyStudy::WriteDraftJob.stub(:perform_later, refuse) { start }

    assert_predicate draft, :failed?
    assert_predicate draft.reload, :failed?
    assert_equal 0, @household.family_study_drafts.counted_today.count
  end

  test "start refuses the 11th draft of the day with a :limit error and creates nothing" do
    10.times { family_study_draft(status: "drafted") }

    draft = nil
    assert_no_difference [ -> { Chat.count }, -> { FamilyStudy::Draft.count } ] do
      assert_no_enqueued_jobs { draft = start }
    end

    assert_not draft.persisted?
    assert draft.errors.added?(:base, :limit)
  end

  test "start doesn't count failed and flagged drafts toward the limit" do
    5.times { family_study_draft(status: "failed") }
    5.times { family_study_draft(status: "flagged") }

    assert_predicate start, :persisted?
  end

  test "start with an invalid prompt creates nothing" do
    draft = nil
    assert_no_difference [ -> { Chat.count }, -> { FamilyStudy::Draft.count } ] do
      assert_no_enqueued_jobs { draft = start(prompt: "") }
    end

    assert_equal [ "can't be blank" ], draft.errors[:prompt]
  end

  # Two requests at once can't both take the 10th: the count runs after the household's row is locked, in the
  # same transaction as the insert, so the second waits for the first to commit and then counts its draft.
  test "two starts racing for the 10th: the count and the insert run under the household's lock" do
    9.times { family_study_draft(status: "drafted") }
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| queries << payload[:sql] }

    start
    ActiveSupport::Notifications.unsubscribe(subscriber)

    lock = queries.index { it.match?(/FROM "households" .* FOR UPDATE/) }
    count = queries.index { it.match?(/SELECT COUNT\(\*\) FROM "family_study_drafts"/) }
    insert = queries.index { it.start_with?('INSERT INTO "family_study_drafts"') }
    release = queries.index { it.match?(/RELEASE SAVEPOINT/) }
    assert_operator lock, :<, count
    assert_operator count, :<, insert
    assert_operator insert, :<, release
    assert start.errors.added?(:base, :limit), "the next start finds the 10th taken"
  end

  test "stop sets stopped while drafting, and nothing else" do
    draft = family_study_draft

    assert draft.stop
    assert_predicate draft, :stopped?

    drafted = family_study_draft(status: "drafted")
    assert_not drafted.stop
    assert_predicate drafted, :drafted?
  end

  test "discard sets discarded unless drafting, and never deletes" do
    drafted = family_study_draft(status: "drafted")

    assert_no_difference -> { FamilyStudy::Draft.count } do
      assert drafted.discard
    end
    assert_predicate drafted, :discarded?

    drafting = family_study_draft
    assert_not drafting.discard
    assert_predicate drafting, :drafting?
  end

  test "stop_or_discard stops a drafting draft and discards a done one" do
    drafting = family_study_draft
    drafted = family_study_draft(status: "drafted")

    drafting.stop_or_discard
    drafted.stop_or_discard

    assert_predicate drafting, :stopped?
    assert_predicate drafted, :discarded?
  end

  test "stop_or_discard discards a draft whose job finished after it was read" do
    draft = family_study_draft
    FamilyStudy::Draft.where(id: draft.id).update_all(status: "drafted")

    assert draft.stop_or_discard
    assert_predicate draft, :discarded?
  end

  test "discarding a failed or flagged draft does nothing, so it still doesn't count" do
    drafts = %w[ failed flagged ].map { family_study_draft(status: it) }

    drafts.each { assert_not it.discard }
    assert_equal %w[ failed flagged ], drafts.map(&:status)
    assert_equal 0, @household.family_study_drafts.counted_today.count
  end

  test "the household and the person have their drafts" do
    draft = family_study_draft

    assert_includes @household.family_study_drafts, draft
    assert_includes users(:head).family_study_drafts, draft
  end

  private
    def start(prompt: "Prayer as a family")
      FamilyStudy::Draft.start(household: @household, user: users(:head), prompt: prompt, length_minutes: 45, young_children: true)
    end
end
