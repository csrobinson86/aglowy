class DashboardsController < ApplicationController
  include HouseholdScoped

  def show
    authorize Current.household, :show?
    @memberships = Current.household.memberships.active.preloaded.by_role
  end
end
