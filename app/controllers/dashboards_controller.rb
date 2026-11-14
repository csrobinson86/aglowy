class DashboardsController < ApplicationController
  include HouseholdScoped

  def show
    authorize Current.household, :show?
  end
end
