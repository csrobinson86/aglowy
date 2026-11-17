# The Meetings section of Household settings, for heads and adults (docs/design/meeting-helper.md, Pages).
class Households::MeetingTimesController < ApplicationController
  include HouseholdScoped

  # The settings page shows heads the members and roles too.
  before_action { @memberships = Current.household.memberships.active.preloaded.by_role }

  def update
    authorize Current.household, :manage_meetings?
    # A copy, as in Households::SettingsController, so the form shows what was refused without touching Current.
    @household = Current.user.active_households.find(Current.household.id)

    if @household.change_meeting_times(**meeting_times_params)
      redirect_to edit_household_settings_household_path, notice: "Meeting times saved."
    else
      render "households/settings/edit", status: :unprocessable_content
    end
  end

  private
    # Each one named, so a field left out of the request is blank, not a missing keyword.
    def meeting_times_params
      times = params.expect(household: Household::MEETING_TIME_ATTRIBUTES)
      { midweek_wday: times[:midweek_meeting_wday], midweek_time: times[:midweek_meeting_time],
        weekend_wday: times[:weekend_meeting_wday], weekend_time: times[:weekend_meeting_time] }
    end
end
