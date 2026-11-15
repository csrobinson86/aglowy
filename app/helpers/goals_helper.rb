module GoalsHelper
  # "Completed on October 4 by Maria. Archived on August 30 by Daniel." for a finished goal's Banner.
  def goal_finished_text(goal)
    [ ("Completed on #{goal_long_date(goal, goal.completion.created_at)} by #{goal.completion.completed_by.name}." if goal.completed?),
      ("Archived on #{goal_long_date(goal, goal.archival.created_at)} by #{goal.archival.archived_by.name}." if goal.archived?) ].compact.join(" ")
  end

  private
    # "October 4", with the year when it isn't this year, in the household's time zone.
    def goal_long_date(goal, time)
      zone = goal.household&.time_zone || Time.zone
      date = time.in_time_zone(zone).to_date
      date.strftime(date.year == Time.current.in_time_zone(zone).year ? "%B %-d" : "%B %-d, %Y")
    end
end
