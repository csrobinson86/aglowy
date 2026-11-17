# Settings → Calendar, for every role: Share my times (docs/design/calendar.md, Settings → Calendar). It saves the
# person, never Current.membership (docs/design/settings.md, Traps).
class Settings::CalendarsController < ApplicationController
  include HouseholdScoped

  before_action { authorize Current.user, :update? }

  def show
    @memberships = Current.user.memberships.active.by_household_name.includes(:time_sharing)
  end
end
