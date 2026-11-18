require "test_helper"

# One day's brief, made from a copy of the person's plan (docs/design/daily-brief.md, DailyBrief; Traps 6 and 7).
# Tuesday 17 November 2026, 6:00 AM in Hannah's zone.
class DailyBriefTest < ActiveSupport::TestCase
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

  private
    def unseen_days(count)
      count.times { |ago| DailyBrief.for(@user, on: Date.new(2026, 11, 16) - ago) }
    end
end
