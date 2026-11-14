# Tops every ongoing repeating study up to the horizon, daily from config/recurring.yml (scheduling rule 4).
class FamilyStudies::ExtendSessionsJob < ApplicationJob
  def perform
    horizon = FamilyStudy.horizon

    FamilyStudy.repeating.ongoing.preloaded.find_each { it.extend_sessions(through: horizon) }
  end
end
