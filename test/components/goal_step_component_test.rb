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
    assert_no_selector "button:not(.goal-step__open)"
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
    assert_no_selector "button[autofocus]"
  end

  test "the toggle just pressed gets focus back when its row is redrawn" do
    render_inline(GoalStepComponent.new(step: preloaded(:parables), tickable: [ users(:eli).id, users(:sofia).id ], focused: users(:sofia).id))

    assert_selector "button[autofocus]", count: 1, text: "Sofia Child"
  end

  test "a child's own steps are highlighted, and only their own toggle is enabled" do
    render_inline(GoalStepComponent.new(step: preloaded(:parables), tickable: [ users(:eli).id ], highlighted: true))

    assert_selector ".goal-step--yours"
    assert_selector "form button[aria-pressed=true]:not([disabled])", text: "Eli Child done"
    assert_selector "button[disabled][aria-pressed=false]", text: "Sofia Child"
    assert_selector "form", count: 1
  end

  test "a finished goal's steps have no checkbox or toggles, only what's done" do
    goals(:gospels).complete(by: users(:spouse))

    render_inline(GoalStepComponent.new(step: preloaded(:read_matthew)))
    assert_no_selector "input[type=checkbox]"
    assert_selector "svg.octicon-check-circle-fill.color-fg-success[role=img][aria-label=Done]"
    assert_text "Everyone · Done together · Dec 12"

    render_inline(GoalStepComponent.new(step: preloaded(:parables)))
    assert_no_selector "input[type=checkbox]"
    assert_no_selector "button:not(.goal-step__open)"
    assert_selector "svg.octicon-circle.color-fg-muted[role=img][aria-label='Not done']"
    assert_text "Eli Child done · waiting on Sofia Child"
  end

  test "linked to a study" do
    study = households(:home).schedule_family_study(frequency: :weekly, starts_on: Date.new(2027, 2, 2), time_of_day: "19:00")
    goal_steps(:read_luke).update!(family_study: study)
    first_session = study.sessions.order(:recurrence_at).first

    render_inline(GoalStepComponent.new(step: preloaded(:read_luke), schedulable: true))

    session_path = "/#{households(:home).id}/family_studies/#{study.id}/sessions/#{first_session.id}"
    assert_selector "a[href='#{session_path}'][data-turbo-frame=_top]", text: "Family study · Tue, Feb 2"
    assert_selector "a[href='#{session_path}'] svg.octicon-book"
    assert_no_link "Schedule as a family study"
  end

  test "schedulable" do
    step = preloaded(:read_luke)
    render_inline(GoalStepComponent.new(step:, schedulable: true))

    assert_selector "a[href='/#{households(:home).id}/family_studies/new?goal_step_id=#{step.id}'][data-turbo-frame=_top]", text: "Schedule as a family study"
    assert_selector "a svg.octicon-calendar"
    assert_no_text "Family study ·"
  end

  test "not schedulable for a child" do
    render_inline(GoalStepComponent.new(step: preloaded(:read_luke), schedulable: false))

    assert_no_link "Schedule as a family study"
  end

  test "not schedulable when the step is done or the goal is finished" do
    render_inline(GoalStepComponent.new(step: preloaded(:read_matthew), schedulable: true))
    assert_no_link "Schedule as a family study"

    goals(:gospels).archive(by: users(:spouse))
    render_inline(GoalStepComponent.new(step: preloaded(:read_luke), schedulable: true))
    assert_no_link "Schedule as a family study"
  end

  test "a personal goal's step is never schedulable" do
    step = goals(:spouse_bible_reading).add_step(title: "Read Genesis")

    render_inline(GoalStepComponent.new(step: Goal.preloaded.find(step.goal_id).steps.sole, schedulable: true))

    assert_no_link "Schedule as a family study"
  end

  test "a personal goal's step names no one and ticks done together in the household it's shown in" do
    goal = goals(:spouse_bible_reading)
    goal.add_step(title: "Read Genesis", due_on: Date.new(2026, 12, 31))

    render_inline(GoalStepComponent.new(step: Goal.preloaded.find(goal.id).steps.sole, household: households(:home), tickable: [ nil ]))

    assert_selector "form[action='/#{households(:home).id}/goals/#{goal.id}/steps/#{goal.steps.sole.id}/completions'] input[type=checkbox]:not([disabled])"
    assert_selector ".goal-step__meta", exact_text: "Due Dec 31"
    assert_no_selector ".avatar"
    assert_no_selector ".sr-only", text: "With"
  end

  test "a personal goal's done step says when" do
    travel_to Time.utc(2026, 11, 14, 12)
    goal = goals(:spouse_bible_reading)
    goal.add_step(title: "Read Genesis", due_on: Date.new(2026, 12, 31)).tick(for: nil, by: users(:spouse))

    render_inline(GoalStepComponent.new(step: Goal.preloaded.find(goal.id).steps.sole, household: households(:home), tickable: [ nil ]))

    assert_selector "input[type=checkbox][checked]"
    assert_selector ".goal-step__meta", exact_text: "Done · Nov 14"
  end

  test "a personal goal shared with the viewer shows its steps read-only, like a finished goal's" do
    goal = goals(:spouse_bible_reading)
    goal.add_step(title: "Read Genesis").tick(for: nil, by: users(:spouse))
    goal.add_step(title: "Read Exodus")

    Goal.preloaded.find(goal.id).steps.each do |step|
      render_inline(GoalStepComponent.new(step:, household: households(:home), read_only: true))

      assert_no_selector "input, button:not(.goal-step__open), form"
      assert_selector "svg[aria-label='#{step.done? ? "Done" : "Not done"}']"
    end
  end

  # On a phone (docs/design/phone.md, A goal; story #411).
  test "a phone row's one muted line: who it's for by first name, then done, due, or who's waiting" do
    {
      read_matthew: "Everyone · done Dec 12",
      draw_map: "Eli · done Jan 18",
      parables: "Eli and Sofia · Eli done, waiting on Sofia",
      read_luke: "Everyone · due Feb 15"
    }.each do |name, line|
      render_inline(GoalStepComponent.new(step: preloaded(name)))
      assert_selector ".goal-step__phone-meta.d-md-none", exact_text: line
      assert_selector ".goal-step__meta.d-none.d-md-block"
    end
  end

  test "a personal goal's phone row says only Done or Due" do
    goal = goals(:spouse_bible_reading)
    goal.add_step(title: "Genesis", due_on: Date.new(2026, 12, 18))
    render_inline(GoalStepComponent.new(step: Goal.preloaded.find(goal.id).steps.sole, household: households(:home)))
    assert_selector ".goal-step__phone-meta", exact_text: "Due Dec 18"

    goal.steps.sole.tick(for: nil, by: users(:spouse))
    goal.steps.sole.completions.sole.update_column(:created_at, Time.utc(2026, 11, 18, 12))
    render_inline(GoalStepComponent.new(step: Goal.preloaded.find(goal.id).steps.sole, household: households(:home)))
    assert_selector ".goal-step__phone-meta", exact_text: "Done Nov 18"
  end

  test "a phone row's box is the viewer's own part of a named step, and no one else's" do
    step = preloaded(:parables)
    render_inline(GoalStepComponent.new(step:, tickable: [ users(:eli).id, users(:sofia).id ], viewer: users(:sofia)))

    assert_selector ".d-none.d-md-block input[type=checkbox][disabled]"
    assert_selector ".d-md-none form[method=post][action='#{completions_path(step)}?user_id=#{users(:sofia).id}'] input[type=checkbox]:not([checked])"
    assert_selector "label.sr-only", text: "Mark your part of Find three parables and explain one done"
    assert_no_selector ".goal-step__no-box"

    render_inline(GoalStepComponent.new(step:, tickable: [ users(:eli).id, users(:sofia).id ], viewer: users(:spouse)))
    assert_no_selector ".d-md-none input[type=checkbox]"
    assert_selector ".goal-step__no-box.d-md-none"
  end

  test "a phone row shares the desktop's box when it ticks the same part, and has none for someone who can't tick it" do
    render_inline(GoalStepComponent.new(step: preloaded(:read_luke), tickable: [ nil ], viewer: users(:spouse)))
    assert_selector "input[type=checkbox]", count: 1
    assert_no_selector ".d-none.d-md-block input[type=checkbox]"

    render_inline(GoalStepComponent.new(step: preloaded(:draw_map), tickable: [ users(:eli).id ], viewer: users(:spouse)))
    assert_selector ".d-none.d-md-block form input[type=checkbox]"
    assert_selector ".goal-step__no-box"
  end

  test "the pencil shows from md up, and a phone's › opens the step's panel instead" do
    render_inline(GoalStepComponent.new(step: preloaded(:read_luke))) { |component| component.with_edit_form { "The form" } }

    assert_selector "button.d-none.d-md-flex[data-action='goal-step#edit'] svg.octicon-pencil"
    assert_selector "button.d-md-none.goal-step__open[aria-label='Open step: Read Luke together'] svg.octicon-chevron-right"
    assert_selector "button[data-show-dialog-id='#{ActionView::RecordIdentifier.dom_id(goal_steps(:read_luke), :panel)}']"
    assert_selector "button[data-action='goal-step#edit']", count: 1
  end

  test "a phone row's › opens the panel for someone who may not edit the step too" do
    render_inline(GoalStepComponent.new(step: preloaded(:read_luke)))

    assert_selector "button.d-md-none[aria-label='Open step: Read Luke together'] svg.octicon-chevron-right"
    assert_no_selector "svg.octicon-pencil"
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
