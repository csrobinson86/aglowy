class HouseholdsController < ApplicationController
  before_action { authorize Household }

  def index
    @households = Current.user.active_households.order(:name)
  end

  def new
    @household = Household.new
  end

  def create
    @household = Household.new(household_params)

    if @household.valid?
      household = Household.create_with_head(household: household_params, head: Current.user)
      redirect_to household_root_path(household_id: household)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def household_params
    params.expect(household: %i[ name time_zone ])
  end
end
