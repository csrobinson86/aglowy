class DashboardsController < ApplicationController
  include HouseholdScoped

  def show
    authorize Current.household, :show?
    @next_session, *@coming_up = Current.household.family_study_sessions.upcoming.preloaded.limit(4)
  end
end
