# Share my times, on Settings → Calendar: each of the person's active households shared or not, in one save
# (docs/design/calendar.md, Settings → Calendar). A household they aren't in is ignored.
class Settings::TimeSharingsController < ApplicationController
  include HouseholdScoped

  before_action { authorize Current.user, :update? }

  def update
    Current.user.share_times_only_with(params.expect(time_sharing: [ household_ids: [] ])[:household_ids])
    redirect_to household_settings_calendar_path, notice: "Sharing saved."
  end
end
