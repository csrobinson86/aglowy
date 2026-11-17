# Reset link, on Settings → Calendar: a new token for the person's own phone link, so the old one stops working at
# once (docs/design/calendar.md, Settings → Calendar). It resets the person's, never Current.membership's.
class Settings::CalendarFeedsController < ApplicationController
  include HouseholdScoped

  before_action { authorize Current.user, :update? }

  def update
    Current.user.ensure_calendar_feed.reset
    redirect_to household_settings_calendar_path, notice: "Your calendar link is reset."
  end
end
