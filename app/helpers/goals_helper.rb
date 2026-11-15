module GoalsHelper
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
