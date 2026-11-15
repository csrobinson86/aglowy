# frozen_string_literal: true

# One step of a goal: its checkbox, title, who it's for, its due date or who finished it and when, and the
# people's avatars (frame milestone-goal.png). Pass a step from Goal.preloaded, so a page asks no query per step.
# Whoever may change the step passes the edit form, which the Edit button shows in place of the row.
# The checkbox is read-only until ticking arrives.
class GoalStepComponent < ApplicationComponent
  renders_one :edit_form

  attr_reader :step

  delegate :done?, :everyone?, to: :step

  # editing: show the edit form instead of the row, as when a save comes back with an error.
  def initialize(step:, editing: false)
    @step = step
    @editing = editing
  end

  def editing?
    @editing && edit_form?
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
