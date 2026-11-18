require "test_helper"

class DailyBrief::PlanTest < ActiveSupport::TestCase
  STARTERS = {
    "husband_and_father" => [ "As a husband", "As a father", "Reaching out", "Qualities to focus on", "Growing appreciation for Jehovah" ],
    "wife_and_mother" => [ "As a wife", "As a mother", "In the ministry", "Qualities to focus on", "Growing appreciation for Jehovah" ],
    "on_my_own" => [ "In the congregation", "In the ministry", "Qualities to focus on", "Growing appreciation for Jehovah" ],
    "basics" => [ "Qualities to focus on" ]
  }.freeze

  test "start makes seven days and the starter's focus areas for each of the four starters, and sets started_at" do
    freeze_time

    STARTERS.zip(%i[ head spouse grandparent outsider ]).each do |(starter, names), person|
      plan = DailyBrief::Plan.start(users(person), starter:)

      assert plan.persisted?, "expected #{starter} to start"
      assert_equal names, plan.focus_areas.map(&:name), "for #{starter}"
      assert_equal (0..6).to_a, plan.days.map(&:wday)
      assert_equal Time.current, plan.started_at
      assert_equal 300, plan.ready_at_minutes
      assert_equal DailyBrief::Plan::SECTIONS, plan.sections
      assert_equal plan, users(person).reload.daily_brief_plan
    end
  end

  test "start copies the starter's week, each topic under its focus area" do
    plan = DailyBrief::Plan.start(users(:head), starter: "husband_and_father")
    areas = plan.focus_areas.index_by(&:name)
    tuesday = plan.days.find_by!(wday: 2)

    assert_equal %w[ role role role quality appreciation ], plan.focus_areas.map(&:kind)
    assert_equal "1 Timothy 3:8-13", areas["Reaching out"].scriptures
    assert_equal "Matthew – John", tuesday.reading
    assert_equal "Abraham, Moses", tuesday.examples
    assert_equal "Patience, Mildness", tuesday.topic_for(areas["Qualities to focus on"])
    assert_equal "Patient teaching of my children", tuesday.topic_for(areas["As a father"])
    assert_nil tuesday.topic_for(areas["As a husband"])
    assert_nil tuesday.topic_for(areas["Growing appreciation for Jehovah"])
  end

  test "start with no starter, or one that isn't offered, saves nothing and says why" do
    [ nil, "", "everyone" ].each do |starter|
      plan = DailyBrief::Plan.start(users(:head), starter:)

      assert_not plan.persisted?
      assert_equal [ "Choose a plan to start from" ], plan.errors[:starter]
    end
    assert_not DailyBrief::Plan.exists?(user: users(:head))
  end

  test "starting again finds the plan already started and changes nothing" do
    plan = DailyBrief::Plan.start(users(:head), starter: "husband_and_father")

    assert_equal plan, DailyBrief::Plan.start(users(:head), starter: "basics")
    assert_equal 5, plan.focus_areas.count
    assert_equal 7, plan.days.count
  end

  test "ready_by reads the minutes as a time of day" do
    plan = DailyBrief::Plan.new(ready_at_minutes: 300)

    assert_equal "5:00 AM", plan.ready_by
    plan.ready_at_minutes = 450
    assert_equal "7:30 AM", plan.ready_by
  end

  test "ready-by and sections are validated for a friendly message" do
    plan = DailyBrief::Plan.new(user: users(:head), started_at: Time.current, ready_at_minutes: 315, sections: %w[ reading prayer ])

    assert_not plan.valid?
    assert_equal [ "Choose a time from 4:00 to 8:00 AM, on the half hour" ], plan.errors[:ready_at_minutes]
    assert_equal [ "can only be daily_text, reading, faith_example, children and evening" ], plan.errors[:sections]
  end

  test "the database refuses a second plan for one person" do
    DailyBrief::Plan.start(users(:head), starter: "basics")

    assert_raises(ActiveRecord::RecordNotUnique) { DailyBrief::Plan.insert!({ user_id: users(:head).id, started_at: Time.current }) }
  end

  test "the database refuses a ready-by before 4:00 AM" do
    assert_raises(ActiveRecord::CheckViolation) { insert_plan(ready_at_minutes: 210) }
  end

  test "the database refuses a ready-by after 8:00 AM" do
    assert_raises(ActiveRecord::CheckViolation) { insert_plan(ready_at_minutes: 510) }
  end

  test "the database refuses a ready-by that isn't on the half hour" do
    assert_raises(ActiveRecord::CheckViolation) { insert_plan(ready_at_minutes: 315) }
  end

  test "the database refuses a section that isn't one of the five" do
    assert_raises(ActiveRecord::CheckViolation) { insert_plan(sections: %w[ reading prayer ]) }
  end

  test "the plan, its focus areas and its days go with the person" do
    plan = DailyBrief::Plan.start(users(:newcomer), starter: "husband_and_father")

    users(:newcomer).destroy!

    assert_not DailyBrief::Plan.exists?(plan.id)
    assert_not DailyBrief::FocusArea.exists?(plan_id: plan.id)
    assert_not DailyBrief::Day.exists?(plan_id: plan.id)
  end

  test "add_focus_area adds one at the end, or returns it unsaved with the reasons" do
    plan = DailyBrief::Plan.start(users(:head), starter: "husband_and_father")

    area = plan.add_focus_area(kind: "role", name: "At work", gives: "One honest thing.")
    assert area.persisted?
    assert_equal 5, area.position

    seventh = plan.add_focus_area(kind: "role", name: "In the ministry", gives: "One way.")
    assert_not seventh.persisted?
    assert_equal [ "You can have six focus areas at most" ], seventh.errors[:base]
  end

  test "pause makes one pause with its reason, and pausing again changes nothing" do
    plan = DailyBrief::Plan.start(users(:head), starter: "basics")
    assert_not plan.paused?

    pause = plan.pause(reason: "chosen")

    assert plan.paused?
    assert_equal "chosen", pause.reason
    assert_equal pause, plan.pause(reason: "unseen")
    assert_equal [ "chosen" ], DailyBrief::Pause.where(plan:).pluck(:reason)
    assert plan.reload.paused?
  end

  test "resume deletes the pause and sets started_at to now; resuming a plan that isn't paused changes nothing" do
    plan = travel_to(3.days.ago) { DailyBrief::Plan.start(users(:head), starter: "basics") }
    started_at = plan.started_at
    assert_no_changes -> { plan.reload.started_at } do
      assert_equal false, plan.resume
    end
    assert_equal started_at, plan.started_at

    plan.pause(reason: "chosen")
    freeze_time
    assert plan.resume

    assert_not plan.paused?
    assert_not DailyBrief::Pause.exists?(plan:)
    assert_equal Time.current, plan.reload.started_at
    assert_not plan.paused?
  end

  test "a day's dialog has a box for every focus area: Your week's columns, Qualities first, then appreciation" do
    plan = DailyBrief::Plan.start(users(:head), starter: "husband_and_father")

    assert_equal plan.focus_areas.size, plan.day_areas.size
    assert_equal plan.topic_areas, plan.day_areas.first(plan.topic_areas.size)
    assert plan.day_areas.first.quality?
    assert plan.day_areas.last.appreciation?
  end

  test "unpaused is every plan without a pause" do
    paused = DailyBrief::Plan.start(users(:head), starter: "basics")
    running = DailyBrief::Plan.start(users(:spouse), starter: "basics")
    paused.pause(reason: "unseen")

    assert_includes DailyBrief::Plan.unpaused, running
    assert_not_includes DailyBrief::Plan.unpaused, paused
  end

  test "the pause goes with the plan" do
    plan = DailyBrief::Plan.start(users(:head), starter: "basics")
    plan.pause(reason: "chosen")

    plan.destroy!

    assert_not DailyBrief::Pause.exists?(plan_id: plan.id)
  end

  test "the database deletes the pause with its plan" do
    plan = DailyBrief::Plan.start(users(:head), starter: "basics")
    plan.pause(reason: "chosen")

    DailyBrief::Plan.where(id: plan.id).delete_all

    assert_not DailyBrief::Pause.exists?(plan_id: plan.id)
  end

  test "the database refuses a pause with no reason" do
    plan = DailyBrief::Plan.start(users(:head), starter: "basics")

    assert_raises(ActiveRecord::NotNullViolation) { DailyBrief::Pause.insert!({ plan_id: plan.id, reason: nil }) }
  end

  test "a pause's reason is chosen or unseen" do
    pause = DailyBrief::Plan.start(users(:head), starter: "basics").build_pausing(reason: "bored")

    assert_not pause.valid?
    assert_equal [ "is not included in the list" ], pause.errors[:reason]
  end

  test "the database refuses a second pause for one plan" do
    plan = DailyBrief::Plan.start(users(:head), starter: "basics")
    plan.pause(reason: "chosen")

    assert_raises(ActiveRecord::RecordNotUnique) { DailyBrief::Pause.insert!({ plan_id: plan.id, reason: "unseen" }) }
  end

  test "the database refuses a pause reason that isn't chosen or unseen" do
    plan = DailyBrief::Plan.start(users(:head), starter: "basics")

    assert_raises(ActiveRecord::CheckViolation) { DailyBrief::Pause.insert!({ plan_id: plan.id, reason: "bored" }) }
  end

  test "due? from 45 minutes before ready-by, in the person's own zone" do
    plan = started_plan

    assert_not plan.due?(central(4, 14)), "46 minutes before"
    assert plan.due?(central(4, 16)), "44 minutes before"
    assert plan.due?(central(9, 0)), "after it"
  end

  test "due? after ready-by only while there's no brief for today" do
    plan = started_plan
    travel_to(central(5, 0)) { DailyBrief.for(users(:head)) }

    assert_not plan.due?(central(9, 0))
    assert plan.due?(central(9, 0) + 1.day)
  end

  test "due? is false while paused" do
    plan = started_plan
    plan.pause(reason: "chosen")

    assert_not plan.due?(central(9, 0))
  end

  test "due? for a person in another time zone reads their own clock" do
    users(:head).update!(time_zone: "Tokyo")
    plan = started_plan

    # 4:30 AM on 18 November in Tokyo is 7:30 PM on 17 November in UTC.
    assert plan.due?(Time.utc(2026, 11, 17, 19, 30))
    assert_not plan.due?(Time.utc(2026, 11, 17, 19, 0))
  end

  test "a plan started today isn't due even after ready-by, and is the next morning" do
    users(:head).update!(time_zone: "Central Time (US & Canada)")
    plan = travel_to(central(3, 0)) { DailyBrief::Plan.start(users(:head), starter: "basics") }

    assert_not plan.due?(central(9, 0))
    assert plan.due?(central(5, 0) + 1.day)
  end

  test "gone_unseen? with seven unseen before today" do
    plan = started_plan
    briefs_before_today(7)

    travel_to(central(5, 0)) { assert plan.gone_unseen? }
  end

  test "gone_unseen? is false with six unseen before today and today's unseen" do
    plan = started_plan
    briefs_before_today(6)
    travel_to(central(5, 0)) do
      DailyBrief.for(users(:head))

      assert_not plan.gone_unseen?
    end
  end

  test "gone_unseen? is false when one of the seven was seen" do
    plan = started_plan
    briefs_before_today(7)[3].mark_seen

    travel_to(central(5, 0)) { assert_not plan.gone_unseen? }
  end

  test "gone_unseen? is false when the seven unseen were made before started_at" do
    plan = started_plan
    briefs_before_today(7)
    travel_to(central(4, 0)) do
      plan.pause(reason: "unseen")
      plan.resume
    end

    travel_to(central(5, 0)) { assert_not plan.gone_unseen? }
  end

  test "pause ends a writing writing stopped with its use kept, and leaves finished ones alone" do
    plan = started_plan
    brief = travel_to(central(9, 0)) { DailyBrief.for(users(:head)) }
    yesterday = travel_to(central(9, 0) - 1.day) { DailyBrief.for(users(:head)) }
    running = daily_brief_writing(brief)
    written = daily_brief_writing(yesterday, status: "written", result: { "thread" => "Kept." })
    failed = daily_brief_writing(yesterday, status: "failed")

    plan.pause(reason: "chosen")

    assert_predicate running.reload, :stopped?
    assert Ai::Use.exists?(daily_brief_writing_id: running.id)
    assert_predicate written.reload, :written?
    assert_predicate failed.reload, :failed?
  end

  test "pause leaves someone else's writing alone" do
    plan = started_plan
    users(:spouse).accept_ai_terms(understood: "1")
    other = daily_brief_writing(travel_to(central(9, 0) - 3.days) { DailyBrief::Plan.start(users(:spouse), starter: "basics") }.then { DailyBrief.for(users(:spouse)) })

    plan.pause(reason: "chosen")

    assert_predicate other.reload, :writing?
  end

  test "due? with today's brief and no writing is true with the AI terms and false without" do
    plan = started_plan
    travel_to(central(5, 0)) { DailyBrief.for(users(:head)) }

    assert_not plan.due?(central(9, 0)), "without the AI terms"
    users(:head).accept_ai_terms(understood: "1")
    assert plan.reload.due?(central(9, 0)), "with the AI terms"
  end

  test "due? with today's brief and a writing of any status is false" do
    users(:head).accept_ai_terms(understood: "1")
    plan = started_plan
    writing = daily_brief_writing(travel_to(central(5, 0)) { DailyBrief.for(users(:head)) })

    %w[ writing written off_topic flagged failed stopped ].each do |status|
      writing.update!(status:)
      assert_not plan.due?(central(9, 0)), "with a #{status} writing"
    end
  end

  private
    def insert_plan(**attributes)
      DailyBrief::Plan.insert!({ user_id: users(:head).id, started_at: Time.current, **attributes })
    end

    # Tuesday 17 November 2026 in Hannah's zone, Central Time unless the test changes it.
    def central(hour, minute = 0)
      ActiveSupport::TimeZone["Central Time (US & Canada)"].local(2026, 11, 17, hour, minute)
    end

    # Started on the 1st, ready by 5:00 AM.
    def started_plan
      users(:head).update!(time_zone: "Central Time (US & Canada)") unless users(:head).time_zone
      travel_to(central(9) - 16.days) { DailyBrief::Plan.start(users(:head), starter: "basics") }
    end

    # One brief a day for the days before the 17th, each made on its own morning, none seen.
    def briefs_before_today(count)
      (1..count).map { |ago| travel_to(central(5) - ago.days) { DailyBrief.for(users(:head)) } }
    end
end
