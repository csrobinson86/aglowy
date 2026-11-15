require "test_helper"

class GoalStepComponentTest < ViewComponent::TestCase
  test "everyone step undone" do
    render_inline(GoalStepComponent.new(step: preloaded(:read_luke)))

    assert_selector "input[type=checkbox][disabled]:not([checked])"
    assert_no_selector "form"
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

  test "an everyone step the viewer may tick posts done together" do
    step = preloaded(:read_luke)
    render_inline(GoalStepComponent.new(step:, tickable: [ nil ]))

    assert_selector "form[method=post][action='#{completions_path(step)}'] input[type=checkbox]:not([disabled]):not([checked])"
    assert_selector "form[data-turbo-frame=_top] input[data-action='change->goal-step#tick']"
    assert_selector "label.sr-only", text: "Mark Read Luke together done"
  end

  test "a done step the viewer may tick unticks by deleting its tick" do
    step = preloaded(:read_matthew)
    render_inline(GoalStepComponent.new(step:, tickable: [ nil ]))

    tick = goal_step_completions(:read_matthew_together)
    assert_selector "form[action='#{completions_path(step)}/#{tick.id}'] input[name=_method][value=delete]", visible: :all
    assert_selector "form input[type=checkbox][checked]:not([disabled])"
  end

  test "a step for one person ticks their part" do
    step = preloaded(:share_learned)
    render_inline(GoalStepComponent.new(step:, tickable: [ users(:spouse).id ]))

    assert_selector "form[method=post][action='#{completions_path(step)}?user_id=#{users(:spouse).id}'] input[type=checkbox]"
    assert_no_selector "[role=group]"
  end

  test "a step for two people has a toggle each, and the checkbox only shows progress" do
    step = preloaded(:parables)
    render_inline(GoalStepComponent.new(step:, tickable: [ users(:eli).id, users(:sofia).id ]))

    assert_selector "input[type=checkbox][disabled]"
    assert_no_selector "form input[type=checkbox]"
    group = "[role=group][aria-label='Each person ticks their own part']"
    assert_selector "#{group} form input[name=_method][value=delete] ~ button[aria-pressed=true].goal-step__part--done", text: "Eli Child done"
    assert_selector "#{group} form[method=post][action='#{completions_path(step)}?user_id=#{users(:sofia).id}'] button[aria-pressed=false]", text: "Sofia Child"
  end

  test "a child's own steps are highlighted, and only their own toggle is enabled" do
    render_inline(GoalStepComponent.new(step: preloaded(:parables), tickable: [ users(:eli).id ], highlighted: true))

    assert_selector ".goal-step--yours"
    assert_selector "form button[aria-pressed=true]:not([disabled])", text: "Eli Child done"
    assert_selector "button[disabled][aria-pressed=false]", text: "Sofia Child"
    assert_selector "form", count: 1
  end

  private
    def completions_path(step)
      "/#{households(:home).id}/goals/#{goals(:gospels).id}/steps/#{step.id}/completions"
    end

    def preloaded(name)
      preloaded_step(goal_steps(name).title)
    end

    def preloaded_step(title)
      Goal.preloaded.find(goals(:gospels).id).steps.find { it.title == title }
    end
end
