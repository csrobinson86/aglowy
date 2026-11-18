# Daily at 2am from config/recurring.yml: this week's listening game for each household with the meeting helper on
# (docs/design/listening-game.md, When it runs). A week that failed tries again the next day, until its midweek meeting
# has passed. One household's failure is reported and the rest go on. With a household, only that one's week: turning
# the helper on and accepting the AI terms enqueue it.
class ListeningGame::PrepareJob < ApplicationJob
  def perform(household = nil)
    return household.prepare_this_weeks_listening_game if household

    Household.joins(:meeting_helper).find_each do |each_household|
      each_household.prepare_this_weeks_listening_game
    rescue StandardError => error
      Rails.error.report(error)
    end
  end
end
