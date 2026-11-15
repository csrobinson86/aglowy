# Household settings, heads only: the household's name and time zone, and its members' roles
# (docs/design/invitations.md, Household settings). Roles and removing are Members::RolesController and MembersController.
class Households::SettingsController < ApplicationController
  include HouseholdScoped

  before_action { authorize Current.household, :update? }
  before_action { @memberships = Current.household.memberships.active.preloaded.by_role }

  def edit
    @household = Current.household
  end

  def update
    # A copy, so a refused name doesn't show in the sidebar and page title as if it were saved.
    @household = Current.user.active_households.find(Current.household.id)

    if @household.update_settings(household_params)
      redirect_to edit_household_settings_path, notice: "Household settings saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def household_params
      params.expect(household: %i[ name time_zone ])
    end
end
