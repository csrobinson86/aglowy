require "test_helper"

# A step's panel on a phone (docs/design/phone.md, A goal, The step panel; frame phone-family-goal-step.png).
class GoalStepPanelComponentTest < ViewComponent::TestCase
  test "a step for named people: the meta line, and a box for each person the viewer may tick" do
    render_inline(GoalStepPanelComponent.new(step: preloaded(:parables), tickable: [ users(:eli).id, users(:sofia).id ], viewer: users(:spouse)))

    assert_selector ".goal-step-panel__meta", exact_text: "For Eli and Sofia · Due Feb 28"
    assert_selector "fieldset legend", exact_text: "Who's done it"
    assert_checked_field "Eli"
    assert_unchecked_field "Sofia"
    assert_selector "form[action$='/completions/#{goal_step_completions(:parables_eli).id}'] input[name=_method][value=delete]", visible: :all
    assert_selector "form[action$='/completions?user_id=#{users(:sofia).id}']"
    assert_selector "fieldset .avatar[aria-hidden=true]", count: 2
  end

  test "someone the viewer may not tick is text: done, or not done yet" do
    render_inline(GoalStepPanelComponent.new(step: preloaded(:parables), tickable: [ users(:eli).id ], viewer: users(:eli)))

    assert_checked_field "Eli"
    assert_no_field "Sofia"
    assert_selector "fieldset li", text: "Sofia · not done yet"
  end

  test "a finished goal's panel lists everyone as text and has no controls" do
    step = preloaded(:parables)
    step.goal.build_completion(completed_by: users(:spouse))
    render_inline(GoalStepPanelComponent.new(step:, tickable: [ users(:eli).id, users(:sofia).id ], schedulable: true, viewer: users(:spouse)))

    assert_selector "fieldset li", text: "Eli · done"
    assert_selector "fieldset li", text: "Sofia · not done yet"
    assert_no_selector "input, button, a"
  end

  test "an Everyone step says so, with no Who's done it, and offers Schedule to whoever may schedule it" do
    render_inline(GoalStepPanelComponent.new(step: preloaded(:read_luke), tickable: [ nil ], schedulable: true, viewer: users(:spouse)))

    assert_selector ".goal-step-panel__meta", exact_text: "Everyone · Due Feb 15"
    assert_no_selector "fieldset"
    assert_link "Schedule as a family study", href: "/#{households(:home).id}/family_studies/new?goal_step_id=#{goal_steps(:read_luke).id}"
  end

  test "a done step's meta line says when it was done" do
    render_inline(GoalStepPanelComponent.new(step: preloaded(:read_matthew), viewer: users(:spouse)))

    assert_selector ".goal-step-panel__meta", exact_text: "Everyone · Done Dec 12"
  end

  test "Edit step and Remove step, and the question Remove step asks first, for whoever may change the step" do
    render_inline(GoalStepPanelComponent.new(step: preloaded(:read_luke), viewer: users(:spouse))) { |component| component.with_edit_form { "The form" } }

    assert_selector "button[data-action='goal-step#edit'][data-goal-step-target=editButton]", text: "Edit step"
    assert_selector "button.Button--danger[data-action='goal-step#askToRemove']", text: "Remove step"
    assert_selector "[data-goal-step-target=form][hidden]", text: "The form", visible: :all
    confirm = "[data-goal-step-target=confirm][hidden]"
    assert_selector confirm, text: "Remove this step?", visible: :all
    assert_selector "#{confirm} button[data-action='goal-step#keep']", text: "Cancel", visible: :all
    assert_selector "#{confirm} form[action$='/steps/#{goal_steps(:read_luke).id}'] input[name=_method][value=delete]", visible: :all
    assert_selector "#{confirm} button.Button--danger[type=submit]", text: "Remove step", visible: :all
  end

  test "editing shows the form instead of the panel's facts, as when a save comes back with an error" do
    render_inline(GoalStepPanelComponent.new(step: preloaded(:read_luke), editing: true, viewer: users(:spouse))) { |component| component.with_edit_form { "The form" } }

    assert_selector "[data-goal-step-target=view][hidden]", visible: :all
    assert_selector "[data-goal-step-target=form]:not([hidden])", text: "The form"
  end

  test "without the edit form there's no Edit step or Remove step" do
    render_inline(GoalStepPanelComponent.new(step: preloaded(:read_luke), viewer: users(:eli)))

    assert_no_button "Edit step"
    assert_no_button "Remove step"
  end

  test "a personal goal's step has its due date only" do
    goal = goals(:spouse_bible_reading)
    goal.add_step(title: "Joshua to Esther", due_on: Date.new(2026, 12, 18))
    step = Goal.preloaded.find(goal.id).steps.sole
    render_inline(GoalStepPanelComponent.new(step:, household: households(:home), tickable: [ nil ], viewer: users(:spouse)))

    assert_selector ".goal-step-panel__meta", exact_text: "Due Dec 18"
    assert_no_selector "fieldset"
    assert_no_link "Schedule as a family study"
  end

  test "a personal goal's step with no due date has no meta line" do
    goal = goals(:spouse_bible_reading)
    goal.add_step(title: "Joshua to Esther")
    render_inline(GoalStepPanelComponent.new(step: Goal.preloaded.find(goal.id).steps.sole, household: households(:home), viewer: users(:spouse)))

    assert_no_selector ".goal-step-panel__meta"
  end

  private
    def preloaded(name)
      Goal.preloaded.find(goals(:gospels).id).steps.find { it.id == goal_steps(name).id }
    end
end
