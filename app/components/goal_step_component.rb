# frozen_string_literal: true

# One step of a goal: its checkbox, title, who it's for, its due date or who finished it and when, and the
# people's avatars (frame milestone-goal.png). Pass a step from Goal.preloaded, so a page asks no query per step.
# Whoever may change the step passes the edit form, which the Edit button shows in place of the row.
# An Everyone step, or a step for one person, ticks with its checkbox; a step for two or more people has a
# toggle per person and a checkbox that only shows how far they've got (frame milestone-goal.png).
class GoalStepComponent < ApplicationComponent
  renders_one :edit_form

  attr_reader :step

  delegate :done?, :everyone?, to: :step

  # editing: show the edit form instead of the row, as when a save comes back with an error.
  # tickable: the parts the viewer may tick (Goal::Step#parts the policy allows), so the rest are disabled.
  # highlighted: the step is the viewer's own, for someone who may tick only their own (frame milestone-goal-child.png).
  # focused: whose toggle was just pressed. Turbo disables a pressed button while it submits, which drops its focus,
  # and focuses an autofocus element in the Turbo Stream that answers, so the redrawn toggle gets it back.
  def initialize(step:, editing: false, tickable: [], highlighted: false, focused: nil)
    @step = step
    @editing = editing
    @tickable = tickable
    @highlighted = highlighted
    @focused = focused
  end

  def editing?
    @editing && edit_form?
  end

  def highlighted?
    @highlighted
  end

  # A completed or archived goal takes no ticks, so its steps show only what's done, without controls.
  def open_goal?
    goal.open?
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
      options.merge(url: household_goal_step_completion_path(household_id: goal.household_id, goal_id: goal, step_id: step, id: tick), method: :delete)
    else
      options.merge(url: household_goal_step_completions_path(household_id: goal.household_id, goal_id: goal, step_id: step, user_id: user_id), method: :post)
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
  def meta_text
    [ everyone? ? "Everyone" : names(people), *status, ("Due #{step.due_on.strftime("%b %-d")}" if step.due_on && !done?) ].compact.join(" · ")
  end

  # Whose part is ticked: a user id, or "" for done together. The edit form counts the ticks a change of people clears.
  def ticks
    step.completions.map { it.user_id.to_s }
  end

  private
    def goal
      step.goal
    end

    def status
      if done?
        [ everyone? ? "Done together" : "Done by #{names(people)}", short_date(step.completions.map(&:created_at).max) ]
      elsif mixed?
        ticked, waiting = people.partition { step.done_for?(it) }
        [ "#{names(ticked)} done", "waiting on #{names(waiting)}" ]
      end
    end

    def names(users)
      users.map(&:name).to_sentence
    end

    # "Dec 12", in the household's time zone.
    def short_date(time)
      time.in_time_zone(step.goal.household&.time_zone || Time.zone).strftime("%b %-d")
    end
end
