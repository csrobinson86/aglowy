module GoalsHelper
  # What the viewer may do with a step, for its row and its phone panel (GoalStepComponent): the parts they may tick,
  # whether they may schedule it, whether it's a goal shared with them to read, and whether to highlight a child's own.
  def goal_step_arguments(step)
    tickable = step.parts.select { policy(step.new_tick(it)).create? }
    { household: Current.household, viewer: Current.user, tickable:, read_only: step.goal.personal? && !policy(step.goal).update?,
      schedulable: policy(step).update? && policy(FamilyStudy).create?, highlighted: tickable.any? && !policy(step.goal).update? }
  end

  # "Completed on October 4 by Maria. Archived on August 30 by Daniel." for a finished goal's Banner.
  def goal_finished_text(goal)
    [ ("Completed on #{goal_long_date(goal, goal.completion.created_at)} by #{goal.completion.completed_by.name}." if goal.completed?),
      ("Archived on #{goal_long_date(goal, goal.archival.created_at)} by #{goal.archival.archived_by.name}." if goal.archived?) ].compact.join(" ")
  end

  # The list a goal's page leads back to: My goals for a personal goal, Family goals for the household's.
  # Someone else's goal, shared here, leads back to My goals' Shared tab.
  def goal_list_name(goal)
    goal.personal? ? "My goals" : "Family goals"
  end

  def goal_list_path(goal, **)
    if goal.family?
      household_goals_path(**)
    elsif goal.user_id == Current.user.id
      household_my_goals_path(**)
    else
      household_my_goals_path(status: "shared")
    end
  end

  # Who can read a personal goal, as an Octicon and words: "Private" or "Shared with <households>" to its owner, and
  # "Shared by <owner>" to a member it's shared with (docs/design/goals.md, Pages). Nil for a family goal.
  def goal_audience(goal)
    return unless goal.personal?

    if policy(goal).share?
      households = goal.shared_households
      households.any? ? [ :people, "Shared with #{households.map(&:name).to_sentence}" ] : [ :lock, "Private" ]
    else
      [ :people, "Shared by #{goal.user.name}" ]
    end
  end

  # The goal's facts on one muted line under its title on a phone (docs/design/phone.md, A goal), after the audience's
  # Octicon: "Private · Milestone · Target Dec 31, 2026", or "Milestone · Target Dec 31, 2026 · Set by Maria".
  def goal_meta_line(goal)
    [ goal_audience(goal)&.last, "Milestone", "Target #{goal.target_on.strftime("%b %-d, %Y")}", ("Set by #{goal.set_by.name}" if goal.family?) ].compact.join(" · ")
  end

  # A personal goal's pages select My goals in the sidebar, not Family goals.
  def goal_nav_item(goal)
    content_for :nav_item, "personal_goals" if goal.personal?
  end

  private
    # "October 4", with the year when it isn't this year, in the goal's time zone.
    def goal_long_date(goal, time)
      zone = goal.time_zone
      date = time.in_time_zone(zone).to_date
      date.strftime(date.year == Time.current.in_time_zone(zone).year ? "%B %-d" : "%B %-d, %Y")
    end
end
