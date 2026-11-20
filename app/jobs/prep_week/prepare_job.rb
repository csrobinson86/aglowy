# Hourly from config/recurring.yml, at minute 30 so it doesn't start with the listening game's, so each household with
# Get ready on gets its run at 3am where it lives: its first try at 3am on its own Monday, and a retry at 3am every day
# after while a part still missing a card has its meeting ahead (docs/design/meeting-prep.md, The weekly AI job;
# Trap 7). One household's failure is reported and the rest go on. With a household, only that one's week: turning
# Get ready on and accepting the AI terms enqueue it.
class PrepWeek::PrepareJob < ApplicationJob
  def perform(household = nil)
    return household.prepare_this_weeks_meeting_prep if household

    Household.joins(:meeting_prep).includes(:meeting_helper, :meeting_prep).at_local_hour(3).find_each do |each_household|
      each_household.prepare_this_weeks_meeting_prep
    rescue StandardError => error
      Rails.error.report(error)
    end
  end
end
