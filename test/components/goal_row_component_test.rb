require "test_helper"

class GoalRowComponentTest < ViewComponent::TestCase
  setup { travel_to Time.utc(2026, 11, 14, 12) }

  test "active with progress" do
    render_inline(GoalRowComponent.new(goal: preloaded(:gospels)))

    assert_selector "h2 a[href='/#{households(:home).id}/goals/#{goals(:gospels).id}']", text: "Read the four Gospels together"
    assert_selector ".Label", text: "Milestone"
    assert_text "Target Mar 31, 2027"
    assert_selector ".Progress .Progress-item[style*='width: 42%']"
    assert_text "3 of 7 steps"
    assert_text "Next: Read Luke together · due Feb 15"
    assert_selector ".avatar", count: 5
    assert_selector ".sr-only", text: "With Hannah Head, Sam Spouse, Charlie Child, Eli Child, and Sofia Child"
  end

  test "the next step names the people it's for" do
    goal_steps(:read_luke).tick(for: nil, by: users(:spouse))

    render_inline(GoalRowComponent.new(goal: preloaded(:gospels)))

    assert_text "Next: Find three parables and explain one · Eli Child and Sofia Child · due Feb 28"
  end

  test "completed" do
    render_inline(GoalRowComponent.new(goal: preloaded(:proverbs)))

    assert_selector "h2", text: "Read Proverbs together"
    assert_text "Completed Oct 30"
    assert_text "Marked complete by Sam Spouse"
    assert_no_text "Next:"
  end

  test "archived" do
    render_inline(GoalRowComponent.new(goal: preloaded(:songs)))

    assert_selector "h2", text: "Learn the new songs"
    assert_text "Archived Oct 1"
    assert_text "Archived by Sam Spouse"
  end

  test "completed, then archived" do
    goals(:gospels).complete(by: users(:head))
    travel 1.day
    goals(:gospels).archive(by: users(:spouse))

    render_inline(GoalRowComponent.new(goal: preloaded(:gospels)))

    assert_text "Archived Nov 15"
    assert_text "Completed Nov 14 · archived by Sam Spouse"
  end

  test "a date from another year shows the year" do
    travel_to Time.utc(2027, 2, 1, 12)

    render_inline(GoalRowComponent.new(goal: preloaded(:songs)))

    assert_text "Archived Oct 1, 2026"
  end

  test "no steps" do
    goal = households(:home).goals.create!(title: "Memorize Psalm 23", target_on: Date.new(2027, 4, 30), set_by: users(:spouse))

    render_inline(GoalRowComponent.new(goal: Goal.preloaded.find(goal.id)))

    assert_text "No steps yet"
    assert_selector ".Progress .Progress-item[style*='width: 0%']"
    assert_no_text "Next:"
    assert_no_selector ".avatar"
  end

  test "every step done" do
    goal = households(:home).goals.create!(title: "Memorize Psalm 23", target_on: Date.new(2027, 4, 30), set_by: users(:spouse))
    goal.add_step(title: "Learn verses 1 to 3").tick(for: nil, by: users(:spouse))

    render_inline(GoalRowComponent.new(goal: Goal.preloaded.find(goal.id)))

    assert_text "1 of 1 step"
    assert_text "Every step is done"
  end

  private
    def preloaded(name)
      Goal.preloaded.find(goals(name).id)
    end
end
