# frozen_string_literal: true

# One step of a goal: its checkbox, title, who it's for, its due date or who finished it and when, and the
# people's avatars (frame milestone-goal.png). Pass a step from Goal.preloaded, so a page asks no query per step.
# Whoever may change the step passes the edit form, which the Edit button shows in place of the row.
# An Everyone step, or a step for one person, ticks with its checkbox; a step for two or more people has a
# toggle per person and a checkbox that only shows how far they've got (frame milestone-goal.png).
class GoalStepComponent < ApplicationComponent
  renders_one :edit_form

  attr_reader :step, :household

  delegate :done?, :everyone?, to: :step

  # household: the one whose pages the step is shown in. A personal goal has none of its own, so its page passes it.
  # editing: show the edit form instead of the row, as when a save comes back with an error.
  # tickable: the parts the viewer may tick (Goal::Step#parts the policy allows), so the rest are disabled.
  # highlighted: the step is the viewer's own, for someone who may tick only their own (frame milestone-goal-child.png).
  # schedulable: the viewer may schedule the step as a family study (heads and adults, frame milestone-goal.png).
  # read_only: a personal goal shared with the viewer, which shows its steps like a finished goal's, without controls.
  # focused: whose toggle was just pressed. Turbo disables a pressed button while it submits, which drops its focus,
  # and focuses an autofocus element in the Turbo Stream that answers, so the redrawn toggle gets it back.
  def initialize(step:, household: step.goal.household, editing: false, tickable: [], highlighted: false, schedulable: false, read_only: false, focused: nil)
    @step = step
    @read_only = read_only
    @household = household
    @editing = editing
    @tickable = tickable
    @highlighted = highlighted
    @schedulable = schedulable
    @focused = focused
  end

  def editing?
    @editing && edit_form?
  end

  def highlighted?
    @highlighted
  end

  # A completed or archived goal takes no ticks, and nor does a goal shared with the viewer, so its steps
  # show only what's done, without controls.
  def ticking?
    goal.open? && !@read_only
  end

  # A family goal's open, undone step with no study yet (docs/design/goals.md, "Schedule a step as a study").
  def schedulable?
    @schedulable && goal.family? && ticking? && !done? && study.nil?
  end

  def schedule_path
    new_household_family_study_path(household_id: goal.household_id, goal_step_id: step.id)
  end

  def study
    step.family_study
  end

  # The study's first session: "Family study · Tue, Feb 3", in the household's time zone.
  def first_session
    study.first_session
  end

  def first_session_label
    "Family study · #{l(first_session.scheduled_at.in_time_zone(goal.household.time_zone), format: :step_study)}"
  end

  def first_session_path
    household_family_study_session_path(household_id: goal.household_id, family_study_id: study, id: first_session)
  end

  # Two or more people, each ticking their own part.
  def several?
    step.parts.many?
  end

  def checkbox_tickable?
    !several? && tickable?(step.parts.first)
  end

  def tickable?(user_id)
    user_id.in?(@tickable)
  end

  def focused?(user_id)
    user_id == @focused
  end

  # Ticking posts the part (no user_id for done together); unticking deletes its tick. The answer is a Turbo Stream;
  # a refusal redirects, and _top lets it replace the page rather than look for this step's frame there.
  def tick_form_options(user_id)
    options = { data: { turbo_frame: "_top" } }

    if (tick = step.tick_for(user_id))
      options.merge(url: household_goal_step_completion_path(household_id: household.id, goal_id: goal, step_id: step, id: tick), method: :delete)
    else
      options.merge(url: household_goal_step_completions_path(household_id: household.id, goal_id: goal, step_id: step, user_id: user_id), method: :post)
    end
  end

  # Some of a named step's people have ticked, not all.
  def mixed?
    !everyone? && !done? && step.completions.any?
  end

  # Everyone on a family goal is every active member.
  def people
    everyone? ? step.goal.assignable_users : step.assignments.map(&:user)
  end

  # "Everyone · Due Feb 15", "Eli · Done by Eli · Jan 18", "Eli and Sofia · Eli done · waiting on Sofia · Due Feb 28".
  # A personal goal's steps are only ever the owner's, so they say no one: "Due Feb 15", "Done · Jan 18".
  def meta_text
    [ (for_text if goal.family?), *status, ("Due #{step.due_on.strftime("%b %-d")}" if step.due_on && !done?) ].compact.join(" · ")
  end

  # Whose part is ticked: a user id, or "" for done together. The edit form counts the ticks a change of people clears.
  def ticks
    step.completions.map { it.user_id.to_s }
  end

  private
    def goal
      step.goal
    end

    def for_text
      everyone? ? "Everyone" : names(people)
    end

    def status
      if done?
        [ done_text, short_date(step.completions.map(&:created_at).max) ]
      elsif mixed?
        ticked, waiting = people.partition { step.done_for?(it) }
        [ "#{names(ticked)} done", "waiting on #{names(waiting)}" ]
      end
    end

    def done_text
      if goal.personal?
        "Done"
      elsif everyone?
        "Done together"
      else
        "Done by #{names(people)}"
      end
    end

    def names(users)
      users.map(&:name).to_sentence
    end

    # "Dec 12", in the goal's time zone.
    def short_date(time)
      time.in_time_zone(goal.time_zone).strftime("%b %-d")
    end
end
