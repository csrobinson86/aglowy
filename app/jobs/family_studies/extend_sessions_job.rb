# Tops every ongoing repeating study up to the horizon, daily from config/recurring.yml (scheduling rule 4).
# One that fails is reported and the rest go on.
class FamilyStudies::ExtendSessionsJob < ApplicationJob
  def perform
    horizon = FamilyStudy.horizon

    each_reporting_failures(FamilyStudy.repeating.ongoing.preloaded) { it.extend_sessions(through: horizon) }
  end
end
