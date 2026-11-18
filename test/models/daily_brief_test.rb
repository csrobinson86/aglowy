require "test_helper"

# One day's brief, made from a copy of the person's plan (docs/design/daily-brief.md, DailyBrief; Traps 6 and 7).
# Tuesday 17 November 2026, 6:00 AM in Hannah's zone.
class DailyBriefTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:head)
    @user.update!(time_zone: "Central Time (US & Canada)")
    travel_to Time.utc(2026, 11, 17, 12)
    @plan = travel_to(3.days.ago) { DailyBrief::Plan.start(@user, starter: "husband_and_father") }
  end

  test "for makes one brief a day and returns the same one again" do
    brief = assert_difference -> { DailyBrief.count } do
      DailyBrief.for(@user)
    end

    assert_equal Date.new(2026, 11, 17), brief.on
    assert_equal @user, brief.user
    assert_no_difference(-> { DailyBrief.count }) { assert_equal brief, DailyBrief.for(@user) }
  end

  test "for makes none for a paused plan, and still finds one already made" do
    yesterday = DailyBrief.for(@user, on: Date.new(2026, 11, 16))
    @plan.pause(reason: "chosen")

    assert_no_difference(-> { DailyBrief.count }) { assert_nil DailyBrief.for(@user) }
    assert_equal yesterday, DailyBrief.for(@user, on: Date.new(2026, 11, 16))
  end

  test "for makes none for someone with no plan" do
    assert_nil DailyBrief.for(users(:spouse))
  end

  test "with pause_if_unseen, seven unseen before today and no brief today pause it with unseen and make none" do
    unseen_days(7)

    assert_no_difference(-> { DailyBrief.count }) { assert_nil DailyBrief.for(@user, pause_if_unseen: true) }
    assert_equal "unseen", @plan.reload.pausing.reason
  end

  test "with pause_if_unseen, today's brief already made is found and never pauses" do
    unseen_days(7)
    today = DailyBrief.for(@user)

    assert_equal today, DailyBrief.for(@user, pause_if_unseen: true)
    assert_not @plan.reload.paused?
  end

  test "without pause_if_unseen, seven unseen still make today's brief" do
    unseen_days(7)

    assert DailyBrief.for(@user)
    assert_not @plan.reload.paused?
  end

  test "the database refuses a second brief for one person on one day, so two calls at once make one" do
    DailyBrief.for(@user)

    assert_raises(ActiveRecord::RecordNotUnique) do
      DailyBrief.insert!({ user_id: @user.id, on: Date.new(2026, 11, 17), plan: {} })
    end
  end

  test "the copy holds the sections, the focus areas and the weekday's row" do
    @plan.update!(sections: %w[ daily_text reading ])
    brief = DailyBrief.for(@user).reload
    qualities = @plan.focus_areas.find_by!(kind: "quality")

    assert_equal %w[ daily_text reading ], brief.sections
    assert brief.section?(:reading)
    assert_not brief.section?(:faith_example)
    assert_equal @plan.focus_areas.map(&:name), brief.focus_areas.map(&:name)
    assert_equal "1 Timothy 3:8-13", brief.focus_areas.find { it.name == "Reaching out" }.scriptures
    assert_equal 2, brief.day.wday
    assert_equal "Matthew – John", brief.day.reading
    assert_equal "Abraham, Moses", brief.day.examples
    assert_equal "Patience, Mildness", brief.day.topic_for(brief.focus_areas.find(&:quality?))
    assert_equal qualities.id, brief.focus_areas.find(&:quality?).id
  end

  test "editing the plan afterwards doesn't change the brief" do
    brief = DailyBrief.for(@user)
    @plan.reload

    @plan.update!(sections: %w[ reading ])
    @plan.focus_areas.find { it.name == "As a husband" }.update!(name: "At home")
    @plan.days.find_by!(wday: 2).revise(reading: "Psalms")
    @plan.focus_areas.find_by!(kind: "appreciation").destroy!
    brief.reload

    assert_equal DailyBrief::Plan::SECTIONS, brief.sections
    assert_includes brief.focus_areas.map(&:name), "As a husband"
    assert_includes brief.focus_areas.map(&:name), "Growing appreciation for Jehovah"
    assert_equal "Matthew – John", brief.day.reading
  end

  test "reading_start is the chapter the reading names, or the first chapter of its first book" do
    brief = DailyBrief.new(plan: { "day" => { "wday" => 2, "reading" => "Matthew – John" } })
    assert_equal "Matthew 1", brief.reading_start.to_s
    assert_equal "Song of Solomon 1", DailyBrief.new(plan: { "day" => { "reading" => "Song of Solomon, Psalms" } }).reading_start.to_s
    assert_equal "Matthew 1", DailyBrief.new(plan: { "day" => { "reading" => "Matthew-John" } }).reading_start.to_s
    assert_equal "Matthew 1", DailyBrief.new(plan: { "day" => { "reading" => "Matthew To John" } }).reading_start.to_s
    assert_equal "Matthew 5", DailyBrief.new(plan: { "day" => { "reading" => "Matthew 5 to John" } }).reading_start.to_s
    assert_equal "Psalm 1", DailyBrief.new(plan: { "day" => { "reading" => "Psalms 1-41" } }).reading_start.to_s
    assert_equal "Matthew 5", DailyBrief.new(plan: { "day" => { "reading" => "Matthew 5:3–12" } }).reading_start.to_s
    assert_equal "Psalm 23", DailyBrief.new(plan: { "day" => { "reading" => "Psalm 23:1" } }).reading_start.to_s
    assert_nil DailyBrief.new(plan: { "day" => { "reading" => nil } }).reading_start
    assert_nil DailyBrief.new(plan: { "day" => { "reading" => "The gospels" } }).reading_start
  end

  test "a copy keeps reading when it has a key its records no longer have" do
    brief = DailyBrief.new(plan: { "focus_areas" => [ { "name" => "As a husband", "kind" => "role", "retired" => "x" } ],
                                   "day" => { "wday" => 2, "reading" => "Acts", "retired" => "x" } })

    assert_equal [ "As a husband" ], brief.focus_areas.map(&:name)
    assert_equal "Acts", brief.day.reading
  end

  test "daily_text_url is the day's text on wol.jw.org" do
    assert_equal "https://wol.jw.org/en/wol/dt/r1/lp-e/2026/11/17", DailyBrief.new(on: Date.new(2026, 11, 17)).daily_text_url
    assert_equal "https://wol.jw.org/en/wol/dt/r1/lp-e/2027/1/5", DailyBrief.new(on: Date.new(2027, 1, 5)).daily_text_url
  end

  test "evening_open? from 6:00 PM in the person's zone, for the brief's own day" do
    brief = DailyBrief.for(@user)
    central = ActiveSupport::TimeZone["Central Time (US & Canada)"]

    assert_not brief.evening_open?(central.local(2026, 11, 17, 17, 59))
    assert brief.evening_open?(central.local(2026, 11, 17, 18))
    assert brief.evening_open?(central.local(2026, 11, 18, 9)), "an earlier day's evening has opened"
    assert_not brief.evening_open?(Time.utc(2026, 11, 17, 23, 59)), "5:59 PM in Chicago, though 6 PM has passed in UTC"
  end

  test "evening_questions are the newest writing's, only when evening is on in the brief's copy of the plan" do
    brief = DailyBrief.for(@user)
    assert_empty brief.evening_questions, "no writing"

    daily_brief_writing(brief, status: "written", result: { "thread" => "A thread", "evening" => [ { "text" => "Where did I wait?", "from" => "quality" } ] })
    assert_equal [ "Where did I wait?" ], brief.reload.evening_questions.pluck("text")

    brief.plan["sections"] -= [ "evening" ]
    assert_empty brief.evening_questions, "evening off"
  end

  test "mark_seen sets seen_at once" do
    brief = DailyBrief.for(@user)

    brief.mark_seen
    first = brief.reload.seen_at
    assert_equal Time.current, first

    travel 1.hour
    brief.mark_seen
    assert_equal first, brief.reload.seen_at
  end

  test "mark_seen keeps the first time when two pages opened it at once" do
    brief = DailyBrief.for(@user)
    other_page = DailyBrief.find(brief.id)
    brief.mark_seen
    first = brief.reload.seen_at

    travel 1.second
    other_page.mark_seen

    assert_equal first, brief.reload.seen_at
  end

  test "the copy is encrypted" do
    brief = DailyBrief.for(@user)
    raw = DailyBrief.connection.select_value(DailyBrief.where(id: brief.id).select(:plan).to_sql)

    assert_not_includes raw, "As a husband"
    assert_not_includes raw, "Matthew"
    assert_equal "Matthew – John", brief.reload.day.reading
  end

  test "the database refuses a brief for a person who doesn't exist" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      DailyBrief.insert!({ user_id: SecureRandom.uuid_v7, on: Date.new(2026, 11, 17), plan: {} })
    end
  end

  test "the database refuses a brief with no person" do
    assert_raises(ActiveRecord::NotNullViolation) { DailyBrief.insert!({ user_id: nil, on: Date.new(2026, 11, 17), plan: {} }) }
  end

  test "the database refuses a brief with no date" do
    assert_raises(ActiveRecord::NotNullViolation) { DailyBrief.insert!({ user_id: @user.id, on: nil, plan: {} }) }
  end

  test "the database refuses a brief with no copy" do
    assert_raises(ActiveRecord::NotNullViolation) { DailyBrief.insert!({ user_id: @user.id, on: Date.new(2026, 11, 17), plan: nil }) }
  end

  test "the database deletes the briefs with the person" do
    user = User.create!(name: "Ann")
    DailyBrief.insert!({ user_id: user.id, on: Date.new(2026, 11, 17), plan: {} })

    User.where(id: user.id).delete_all

    assert_not DailyBrief.exists?(user_id: user.id)
  end

  test "briefs go with the person" do
    DailyBrief.for(@user)

    @user.destroy!

    assert_not DailyBrief.exists?(user_id: @user.id)
  end

  test "write makes a writing with its own chat and use, and queues the job once" do
    @user.accept_ai_terms(understood: "1")
    brief = DailyBrief.for(@user)

    writing = nil
    assert_enqueued_jobs(1, only: DailyBrief::WriteJob) { writing = brief.write(by: @user) }

    assert_predicate writing, :persisted?
    assert_predicate writing, :writing?
    assert_equal [ "daily_brief", @user, nil ], [ writing.chat.purpose, writing.chat.user, writing.chat.household ]
    assert_equal [ "daily_brief", @user ], [ writing.use.purpose, writing.use.user ]
    assert_equal [ writing.id ], enqueued_jobs.last["arguments"]
  end

  test "write refuses at 3 today in the person's time zone and allows again on a new day" do
    @user.accept_ai_terms(understood: "1")
    brief = DailyBrief.for(@user)
    zone = ActiveSupport::TimeZone["Central Time (US & Canada)"]
    travel_to zone.local(2026, 11, 17, 23, 0)
    3.times { Ai::Use.create!(user: @user, purpose: "daily_brief") }

    assert_refused(:limit) { brief.write(by: @user) }

    travel_to zone.local(2026, 11, 18, 0, 1)
    assert_predicate brief.write(by: @user), :persisted?
  end

  test "write doesn't count other purposes' uses" do
    @user.accept_ai_terms(understood: "1")
    3.times { Ai::Use.create!(user: @user, purpose: "meeting_part") }

    assert_predicate DailyBrief.for(@user).write(by: @user), :persisted?
  end

  test "write refuses without the AI terms, for a child, and for someone else's brief" do
    brief = DailyBrief.for(@user)
    assert_refused(:not_allowed) { brief.write(by: @user) }

    users(:spouse).accept_ai_terms(understood: "1")
    assert_refused(:not_allowed) { brief.write(by: users(:spouse)) }

    child = users(:child)
    child.accept_ai_terms(understood: "1")
    DailyBrief::Plan.start(child, starter: "basics").update!(started_at: 3.days.ago)
    assert_refused(:not_allowed) { DailyBrief.for(child).write(by: child) }

    @user.accept_ai_terms(understood: "1")
    @user.memberships.update_all(active: false)
    assert_refused(:not_allowed) { brief.write(by: @user.reload) }
  end

  test "write refuses while one is writing" do
    @user.accept_ai_terms(understood: "1")
    brief = DailyBrief.for(@user)
    daily_brief_writing(brief)

    assert_refused(:busy) { brief.write(by: @user) }
  end

  test "write refuses at 6 writings of the brief even when failed ones gave their uses back" do
    @user.accept_ai_terms(understood: "1")
    brief = DailyBrief.for(@user)
    6.times { daily_brief_writing(brief, status: "failed").use.destroy! }
    assert_equal 3, @user.daily_brief_writings_left_today

    assert_refused(:limit) { brief.write(by: @user) }
  end

  test "write refuses :paused for a paused plan" do
    @user.accept_ai_terms(understood: "1")
    brief = DailyBrief.for(@user)
    @plan.pause(reason: "chosen")

    assert_refused(:paused) { brief.write(by: @user) }
  end

  test "with first: true, write refuses :written once the brief has a writing of any status" do
    @user.accept_ai_terms(understood: "1")
    brief = DailyBrief.for(@user)
    writing = daily_brief_writing(brief, status: "failed")

    %w[ failed stopped off_topic written writing ].each do |status|
      writing.update!(status:)
      assert_refused(:written) { brief.write(by: @user, first: true) }
    end
  end

  # The checks run after the person's row is locked, in the same transaction as the insert, so a second request waits for
  # the first to commit and then sees its writing and its use.
  test "two at once make one, and can't both take the last one: the checks and the insert run under the person's lock" do
    @user.accept_ai_terms(understood: "1")
    brief = DailyBrief.for(@user)
    2.times { Ai::Use.create!(user: @user, purpose: "daily_brief") }
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| queries << payload[:sql] }

    brief.write(by: @user, first: true)
    ActiveSupport::Notifications.unsubscribe(subscriber)

    lock = queries.index { it.match?(/FROM "users" .* FOR UPDATE/) }
    checks = queries.index { it.match?(/FROM "daily_brief_writings"/) }
    count = queries.index { it.match?(/SELECT COUNT\(\*\) FROM "ai_uses"/) }
    insert = queries.index { it.start_with?('INSERT INTO "daily_brief_writings"') }
    release = queries.index { it.match?(/RELEASE SAVEPOINT/) }
    assert_operator lock, :<, checks
    assert_operator lock, :<, count
    assert_operator [ checks, count ].max, :<, insert
    assert_operator insert, :<, release
    assert_refused(:written) { brief.write(by: @user, first: true) }
    brief.writings.update_all(status: "written")
    assert_refused(:limit) { brief.write(by: @user) }
  end

  test "writing is the newest written one" do
    brief = DailyBrief.for(@user)
    daily_brief_writing(brief, status: "written", result: { "thread" => "First." })
    newest = travel(1.minute) { daily_brief_writing(brief, status: "written", result: { "thread" => "Second." }) }
    travel(2.minutes) { daily_brief_writing(brief, status: "failed") }

    assert_equal newest, brief.writing
    assert_predicate brief.writings.last, :failed?
  end

  # Sharing today's thought with the household (docs/design/daily-brief.md, For the children, and sharing; Trap 8).
  test "share_with shares into a household the owner is active in, once, and stop_sharing_with ends it there only" do
    brief = DailyBrief.for(@user)

    2.times { brief.share_with(households(:home)) }
    brief.share_with(households(:parents))

    assert_equal households(:parents, :home).sort_by(&:name), brief.shared_households
    assert brief.shared_with?(households(:home))
    assert_raises(ActiveRecord::RecordNotFound) { brief.share_with(households(:other)) }

    brief.stop_sharing_with(households(:home))

    assert_not brief.shared_with?(households(:home))
    assert_equal [ households(:parents) ], brief.reload.shared_households
  end

  test "shared_with finds a brief only while its owner is active in that household" do
    brief = DailyBrief.for(@user)
    brief.share_with(households(:home))
    assert_equal [ brief ], DailyBrief.shared_with(households(:home)).to_a
    assert_empty DailyBrief.shared_with(households(:parents))

    memberships(:head_in_home).update_column(:active, false)

    assert_empty DailyBrief.shared_with(households(:home))
  end

  test "sharing makes no notification, and stopping a share succeeds with no notifications to withdraw" do
    brief = DailyBrief.for(@user)

    assert_no_difference(-> { Notification.count }) { brief.share_with(households(:home)) }
    assert_difference(-> { DailyBrief::Sharing.count }, -1) { brief.stop_sharing_with(households(:home)) }
    assert_not brief.shared_with?(households(:home))
  end

  test "the database refuses a second sharing of one brief with one household" do
    brief = DailyBrief.for(@user)
    brief.share_with(households(:home))

    assert_raises(ActiveRecord::RecordNotUnique) do
      DailyBrief::Sharing.insert!({ daily_brief_id: brief.id, household_id: households(:home).id })
    end
  end

  test "keep_as_note makes the owner's note titled with the brief's date, with the thread and every section" do
    brief = DailyBrief.for(@user)
    written_writing(brief)

    note = assert_difference(-> { @user.personal_notes.count }) { brief.keep_as_note }

    assert_equal "Daily brief · Tuesday, November 17", note.title
    assert_equal "none", note.color
    text = note.body.to_plain_text
    [ "Today's thread", "Patience is letting Jehovah's timing be Jehovah's timing",
      "Daily text", "What's happening", "Peter is in the home of Cornelius",
      "Bible reading", "Peter wants a faster, kinder ending", "What Jesus already knows about the days ahead",
      "Patience", "How Jesus showed it", "He isn't slow. He waits for people.",
      "Your focus today", "Ask about her day and listen to the end", "Imitate their faith", "Abraham", "For me",
      "For the children", "Have you ever really wanted something right now", "To end the day", "Where did I push for my own timing today?",
      "Pages it used", "Today's text and comment" ].each { assert_includes text, it }
  end

  test "keep_as_note makes every reference a scripture link" do
    brief = DailyBrief.for(@user)
    written_writing(brief)

    references = brief.keep_as_note.reload.scripture_references.map(&:to_s)

    [ "Acts 10:28", "Acts 10:29", "Matthew 16:21-23", "Galatians 5:22, 23", "Luke 22:24-27", "2 Peter 3:9",
      "Ephesians 5:25", "Deuteronomy 6:6, 7", "1 Timothy 3:8", "Genesis 21:5", "Hebrews 6:15", "Acts 7:23-30", "Hebrews 11:27" ]
      .each { assert_includes references, it }
  end

  test "keep_as_note makes a whole chapter in a section's title a scripture link" do
    brief = DailyBrief.for(@user)
    daily_brief_writing(brief, status: "written", result: { "reading" => { "passage" => "Matthew 16", "title" => "<b>Ahead</b>" } })

    note = brief.keep_as_note.reload

    assert_includes note.scripture_references.map(&:to_s), "Matthew 16"
    assert_includes note.body.to_plain_text, "<b>Ahead</b>"
  end

  test "keep_as_note escapes AI text holding HTML, so the reply's markup is only ever text" do
    brief = DailyBrief.for(@user)
    daily_brief_writing(brief, status: "written", sources: [ { "url" => "https://www.jw.org/en/x", "title" => "<b>Page</b>" } ],
      result: { "thread" => %(<script>alert("thread")</script> <a href="https://evil.example">Click</a>),
                "faith" => { "examples" => [ { "name" => "<img src=x onerror=alert(1)>", "lesson" => "<i>Lesson</i>" } ], "for_me" => "<b>Me</b>" } })

    note = brief.keep_as_note.reload
    html = note.body.body.to_html

    assert_no_match(/<script|<img|<i>|<b>|<a [^>]*evil/, html)
    assert_includes note.body.to_plain_text, %(<script>alert("thread")</script>)
    assert_includes note.body.to_plain_text, "<i>Lesson</i>"
  end

  test "keep_as_note with no written writing keeps the parts from the plan" do
    brief = DailyBrief.for(@user)
    daily_brief_writing(brief, status: "failed")

    note = brief.keep_as_note

    text = note.body.to_plain_text
    assert_includes text, "From your plan"
    assert_includes text, "Open the Daily text on wol.jw.org"
    assert_not_includes text, "Today's thread"
    assert_includes note.reload.scripture_references.map(&:to_s), "1 Timothy 3:8-13"
  end

  test "keeping the same brief twice makes a second note" do
    brief = DailyBrief.for(@user)

    assert_difference(-> { @user.personal_notes.count }, 2) { 2.times { brief.keep_as_note } }
  end

  test "the kept note survives the brief's deletion" do
    brief = DailyBrief.for(@user)
    written_writing(brief)
    note = brief.keep_as_note

    brief.destroy!

    assert PersonalNote.exists?(note.id)
    assert_includes note.reload.body.to_plain_text, "Patience is letting Jehovah's timing"
  end

  private
    # Refused with +reason+: nothing made and no job queued.
    def assert_refused(reason)
      refused = nil
      assert_no_difference [ -> { DailyBrief::Writing.count }, -> { Chat.count }, -> { Ai::Use.count } ] do
        assert_no_enqueued_jobs { refused = yield }
      end
      assert refused.errors.added?(:base, reason), "expected #{reason}, got #{refused.errors.details}"
    end

    def unseen_days(count)
      count.times { |ago| DailyBrief.for(@user, on: Date.new(2026, 11, 16) - ago) }
    end

    # The saved reply's fields and pages (test/fixtures/files/ai/daily_brief.json), as the checks keep them.
    def written_writing(brief)
      body = JSON.parse(file_fixture("ai/daily_brief.json").read)
      sources = body["content"].select { it["type"] == "web_search_tool_result" }.flat_map { it["content"] }.map { it.slice("url", "title") }
      daily_brief_writing(brief, status: "written", sources:, result: JSON.parse(body["content"].filter_map { it["text"] }.join).except("off_topic"))
    end
end
