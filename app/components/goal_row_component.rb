# frozen_string_literal: true

# One goal in a list: title, kind, its date, progress, what's next (or who finished it) and the people
# with steps (frames goals-list.png, goals-list-archived.png). Pass a goal from Goal.preloaded, so a list
# asks no query per goal.
class GoalRowComponent < ApplicationComponent
  attr_reader :goal, :household

  delegate :progress, to: :goal

  # household: the one whose pages the list is in. A personal goal has none of its own, so My goals passes it.
  # shared_by: name the goal's owner, for My goals' Shared tab.
  def initialize(goal:, household: goal.household, shared_by: false)
    @goal = goal
    @household = household
    @shared_by = shared_by
  end

  def shared_by?
    @shared_by
  end

  def date_text
    if goal.archived?
      "Archived #{short_date(goal.archival.created_at)}"
    elsif goal.completed?
      "Completed #{short_date(goal.completion.created_at)}"
    else
      "Target #{goal.target_on.strftime("%b %-d, %Y")}"
    end
  end

  def steps_text
    progress.steps_count.zero? ? "No steps yet" : "#{progress.done_count} of #{pluralize(progress.steps_count, "step")}"
  end

  # The next step for an open goal; who finished it otherwise.
  def status_text
    if goal.archived? && goal.completed?
      "Completed #{short_date(goal.completion.created_at)} · archived by #{goal.archival.archived_by.name}"
    elsif goal.archived?
      "Archived by #{goal.archival.archived_by.name}"
    elsif goal.completed?
      "Marked complete by #{goal.completion.completed_by.name}"
    elsif (step = progress.next_step)
      next_step_text(step)
    elsif progress.all_done?
      "Every step is done"
    end
  end

  def people
    progress.people.select { it.steps_count.positive? }
  end

  private
    def next_step_text(step)
      names = step.assignments.map { it.user.name }.to_sentence.presence
      due = "due #{step.due_on.strftime("%b %-d")}" if step.due_on
      [ "Next: #{step.title}", names, due ].compact.join(" · ")
    end

    # "Oct 30", with the year when it isn't this year, in the goal's time zone.
    def short_date(time)
      zone = goal.time_zone
      date = time.in_time_zone(zone).to_date
      date.strftime(date.year == Time.current.in_time_zone(zone).year ? "%b %-d" : "%b %-d, %Y")
    end
end
