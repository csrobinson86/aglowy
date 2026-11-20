# Deletes Get ready weeks more than 8 weeks old, with their cards and sources, daily from config/recurring.yml
# (docs/design/meeting-prep.md, PrepWeek). Her comments and drawings are on her meeting notes, so they stay.
class PrepWeek::PurgeJob < ApplicationJob
  def perform
    PrepWeek.expired.delete_all
  end
end
