# Settings → Meetings: the midweek and weekend meeting times, heads and adults (docs/design/settings.md;
# docs/design/meeting-helper.md, Pages).
class Settings::MeetingsController < ApplicationController
  include HouseholdScoped

  before_action { authorize Current.household, :manage_meetings? }

  def show
    @household = Current.household
  end

  def update
    # A copy, as in Settings::HouseholdsController, so the form shows what was refused without touching Current.
    @household = Current.user.active_households.find(Current.household.id)

    if @household.change_meeting_times(**meeting_times_params)
      redirect_to household_settings_meetings_path, notice: "Meeting times saved."
    else
      render :show, status: :unprocessable_content
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
