require "test_helper"

class GoalStepComponentTest < ViewComponent::TestCase
  test "everyone step undone" do
    render_inline(GoalStepComponent.new(step: preloaded(:read_luke)))

    assert_selector "input[type=checkbox][disabled]:not([checked])"
    assert_selector ".goal-step__title:not(.goal-step__title--done)", text: "Read Luke together"
    assert_text "Everyone · Due Feb 15"
    assert_selector ".sr-only", text: "With Hannah Head, Sam Spouse, Charlie Child, Eli Child, and Sofia Child"
    assert_selector ".avatar", count: 5
    assert_no_selector "button"
  end

  test "done together" do
    render_inline(GoalStepComponent.new(step: preloaded(:read_matthew)))

    assert_selector "input[type=checkbox][disabled][checked]"
    assert_selector ".goal-step__title--done", text: "Read Matthew together"
    assert_text "Everyone · Done together · Dec 12"
    assert_no_text "Due"
  end

  test "one person done" do
    render_inline(GoalStepComponent.new(step: preloaded(:draw_map)))

    assert_selector "input[type=checkbox][checked]"
    assert_selector ".goal-step__title--done", text: "Draw a map of Jesus' travels"
    assert_text "Eli Child · Done by Eli Child · Jan 18"
    assert_selector ".avatar", count: 1
    assert_selector ".sr-only", text: "With Eli Child"
  end

  test "two people, one ticked (mixed)" do
    render_inline(GoalStepComponent.new(step: preloaded(:parables)))

    assert_selector "input[type=checkbox]:not([checked])[data-goal-step-target=checkbox]"
    assert_selector "[data-goal-step-mixed-value=true]"
    assert_selector ".goal-step__title:not(.goal-step__title--done)", text: "Find three parables and explain one"
    assert_text "Eli Child and Sofia Child · Eli Child done · waiting on Sofia Child · Due Feb 28"
    assert_selector ".avatar", count: 2
  end

  test "both people ticked" do
    goal_steps(:parables).tick(for: users(:sofia), by: users(:spouse))
    goal_steps(:parables).completions.find_by(user: users(:sofia)).update_column(:created_at, Time.utc(2027, 2, 2, 19))

    render_inline(GoalStepComponent.new(step: preloaded(:parables)))

    assert_selector "input[type=checkbox][checked]"
    assert_selector "[data-goal-step-mixed-value=false]"
    assert_text "Eli Child and Sofia Child · Done by Eli Child and Sofia Child · Feb 2"
  end

  test "no due date" do
    goals(:gospels).add_step(title: "Sing together")

    render_inline(GoalStepComponent.new(step: preloaded_step("Sing together")))

    assert_selector ".goal-step__title", text: "Sing together"
    assert_selector ".goal-step__meta", exact_text: "Everyone"
  end

  test "long title" do
    title = "Read every chapter of the four Gospels aloud together, " * 4
    goals(:gospels).add_step(title: title.strip)

    render_inline(GoalStepComponent.new(step: preloaded_step(title.strip)))

    assert_selector ".goal-step__title.wb-break-word", text: title.strip
    assert_selector ".min-width-0 .goal-step__title"
  end

  test "an edit form slot adds the Edit button, and editing shows the form instead of the row" do
    step = preloaded(:read_luke)

    render_inline(GoalStepComponent.new(step:)) { |component| component.with_edit_form { "The form" } }
    assert_selector "button[aria-label='Edit step: Read Luke together'][data-action='goal-step#edit']"
    assert_selector "[data-goal-step-target=view]:not([hidden])"
    assert_selector "[data-goal-step-target=form][hidden]", visible: :all, text: "The form"

    render_inline(GoalStepComponent.new(step:, editing: true)) { |component| component.with_edit_form { "The form" } }
    assert_selector "[data-goal-step-target=view][hidden]", visible: :all
    assert_selector "[data-goal-step-target=form]:not([hidden])", text: "The form"
  end

  private
    def preloaded(name)
      preloaded_step(goal_steps(name).title)
    end

    def preloaded_step(title)
      Goal.preloaded.find(goals(:gospels).id).steps.find { it.title == title }
    end
end
