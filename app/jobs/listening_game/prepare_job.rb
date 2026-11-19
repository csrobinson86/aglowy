# Hourly from config/recurring.yml, so each household with the meeting helper on gets its run at 2am where it lives:
# this week's listening game (docs/design/listening-game.md, When it runs). At 2am UTC, a household in New York with a
# Monday meeting would always find its week's meeting passed. A week that failed tries again the next day, until its
# midweek meeting has passed. One household's failure is reported and the rest go on. With a household, only that one's week: turning
# the helper on and accepting the AI terms enqueue it.
class ListeningGame::PrepareJob < ApplicationJob
  def perform(household = nil)
    return household.prepare_this_weeks_listening_game if household

    Household.joins(:meeting_helper).includes(:meeting_helper).at_local_hour(2).find_each do |each_household|
      each_household.prepare_this_weeks_listening_game
    rescue StandardError => error
      Rails.error.report(error)
    end
  end
end
