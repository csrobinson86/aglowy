# Deletes study guides more than 8 weeks old, with their parts and sources, daily from config/recurring.yml
# (docs/design/study-guide.md, StudyGuide). Notes kept from a guide are the person's own, so they stay.
class StudyGuide::PurgeJob < ApplicationJob
  def perform
    StudyGuide.expired.delete_all
  end
end
