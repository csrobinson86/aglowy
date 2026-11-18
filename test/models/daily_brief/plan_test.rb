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
      plan.resume
    end
    assert_equal started_at, plan.started_at

    plan.pause(reason: "chosen")
    freeze_time
    plan.resume

    assert_not plan.paused?
    assert_not DailyBrief::Pause.exists?(plan:)
    assert_equal Time.current, plan.reload.started_at
    assert_not plan.paused?
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

  private
    def insert_plan(**attributes)
      DailyBrief::Plan.insert!({ user_id: users(:head).id, started_at: Time.current, **attributes })
    end
end
