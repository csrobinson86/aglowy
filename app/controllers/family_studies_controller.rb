class FamilyStudiesController < ApplicationController
  include HouseholdScoped

  def index
    authorize FamilyStudy
    @sessions = Current.household.family_study_sessions.ahead.preloaded.limit(10)
  end
end
