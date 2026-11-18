require "test_helper"

class DailyBriefsHelperTest < ActionView::TestCase
  test "verses_label names one verse or several, and says look for when the reference names none" do
    assert_equal "Verse 22", verses_label("Matthew 16:22")
    assert_equal "Verses 21-23", verses_label("Matthew 16:21-23")
    assert_equal "Verses 8, 9", verses_label("Psalm 37:8, 9")
    assert_equal "Look for", verses_label("Matthew 16")
    assert_equal "Look for", verses_label("not a reference")
  end

  test "evening_title follows the count" do
    assert_equal "Four questions to end the day", evening_title(4)
    assert_equal "Three questions to end the day", evening_title(3)
    assert_equal "One question to end the day", evening_title(1)
  end

  test "the focus section adds a linked goal's next step beside its focus area, read from the goal, or the goal alone" do
    users(:head).update!(time_zone: "Central Time (US & Canada)")
    travel_to(Time.utc(2026, 11, 14, 12)) { DailyBrief::Plan.start(users(:head), starter: "husband_and_father") }
    brief = DailyBrief.for(users(:head), on: Date.new(2026, 11, 17))
    goal = users(:head).goals.create!(set_by: users(:head), title: "Qualify as a ministerial servant", target_on: Date.new(2027, 6, 30))
    users(:head).daily_brief_plan.focus_areas.find_by!(position: 2).update!(goal:)
    step = goal.add_step(title: "Ask an elder where I can help")

    rows = ->(written = nil) { focus_section(DailyBrief.find(brief.id), written).rows.to_h { [ it.label, it.note ] } }

    assert_equal({ "As a husband" => nil, "As a father" => nil,
                   "Reaching out" => "Your goal: Qualify as a ministerial servant · next step: Ask an elder where I can help" }, rows.call)
    assert_equal "Your goal: Qualify as a ministerial servant · next step: Ask an elder where I can help",
                 rows.call([ {}, {}, { "action" => "Finish one thing I said I would do." } ])["Reaching out"], "beside the AI's action too"

    step.tick(for: nil, by: users(:head))
    assert_equal "Your goal: Qualify as a ministerial servant", rows.call["Reaching out"], "every step done"
  end

  test "the quality and appreciation sections add a linked goal under their last row, the AI's or the plan's" do
    users(:head).update!(time_zone: "Central Time (US & Canada)")
    plan = travel_to(Time.utc(2026, 11, 14, 12)) { DailyBrief::Plan.start(users(:head), starter: "husband_and_father") }
    goal = users(:head).goals.create!(set_by: users(:head), title: "Be more patient", target_on: Date.new(2027, 6, 30))
    plan.focus_areas.where(kind: %w[ quality appreciation ]).find_each { it.update!(goal:) }
    brief = DailyBrief.find(DailyBrief.for(users(:head), on: Date.new(2026, 11, 17)).id)

    notes = ->(section) { section.rows.to_h { [ it.label, it.note ] }.compact }

    assert_equal({ "From your week" => "Your goal: Be more patient" }, notes.(quality_section(brief, brief.quality_area, nil)))
    assert_equal({ "One way today" => "Your goal: Be more patient" },
                 notes.(quality_section(brief, brief.quality_area, { "what" => "Waiting", "jesus" => "He waited", "today" => "Wait" })))
    assert_equal({ "Think about" => "Your goal: Be more patient" }, notes.(appreciation_section(brief, brief.appreciation_area, nil)))
    assert_equal({ "Think about" => "Your goal: Be more patient" },
                 notes.(appreciation_section(brief, brief.appreciation_area, { "seen" => "His care", "think" => "Where?" })))
  end

  test "evening_from names the section by its name in the brief, or keeps the AI's own word" do
    users(:head).update!(time_zone: "Central Time (US & Canada)")
    travel_to(Time.utc(2026, 11, 14, 12)) { DailyBrief::Plan.start(users(:head), starter: "husband_and_father") }
    brief = DailyBrief.for(users(:head), on: Date.new(2026, 11, 17))
    writing = DailyBrief::Writing.new(result: { "quality" => { "name" => "Patience" } })

    assert_equal "Daily text", evening_from(brief, writing, "daily_text")
    assert_equal "Bible reading", evening_from(brief, writing, "reading")
    assert_equal "Patience", evening_from(brief, writing, "quality")
    assert_equal brief.appreciation_area.name, evening_from(brief, writing, "appreciation")
    assert_equal "Your focus", evening_from(brief, writing, "focus")
    assert_equal "Imitate their faith", evening_from(brief, writing, "faith")
    assert_equal "Looking back honestly", evening_from(brief, writing, "Looking back honestly")
    assert_nil evening_from(brief, writing, "")
  end
end
