class DashboardsController < ApplicationController
  include HouseholdScoped

  # Each list is one limited query; the Welcome empty state reuses them rather than asking again.
  def show
    authorize Current.household, :show?
    @next_session, *@coming_up = Current.household.family_study_sessions.upcoming.preloaded.limit(4)
    @family_goals = Current.household.goals.active.includes(:set_by).limit(3).load
    @my_goals = Current.user.goals.active.limit(3).load
    @meeting_notes = Current.user.meeting_notes.newest_first.limit(2).load
    @welcome = [ @next_session, @family_goals, @my_goals, @meeting_notes ].all?(&:blank?)
  end
end
