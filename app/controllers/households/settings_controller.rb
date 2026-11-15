# Household settings: the household's name and time zone and its members' roles for heads, and the meeting times and
# the meeting helper for heads and adults (docs/design/invitations.md, Household settings; docs/design/meeting-helper.md,
# Trap 10). Roles and removing are Members::RolesController and MembersController; meeting times
# Households::MeetingTimesController; the meeting helper Households::MeetingHelpersController.
class Households::SettingsController < ApplicationController
  include HouseholdScoped

  before_action { @memberships = Current.household.memberships.active.preloaded.by_role }

  def edit
    authorize Current.household
    @household = Current.household
  end

  def update
    authorize Current.household
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
