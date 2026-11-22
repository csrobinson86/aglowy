# Hourly from config/recurring.yml, at minute 15 so it doesn't start with the other weekly jobs, so each person with the
# study guide on gets their run in their 3am hour, by their own clock (docs/design/study-guide.md, The weekly job;
# Trap 6): their first try on their own Monday, and a retry in the same hour each day after for a week still missing
# parts, until it ends there. Only heads and adults somewhere; someone who isn't one any more keeps the setting and is
# skipped. One person's failure is reported and the rest go on. With a person, only theirs: turning the setting on
# enqueues it.
class StudyGuide::PrepareJob < ApplicationJob
  def perform(user = nil)
    return user.prepare_this_weeks_study_guide if user

    User.with_study_guide_on.head_or_adult_somewhere.at_local_hour(3).find_each do |person|
      person.prepare_this_weeks_study_guide
    rescue StandardError => error
      Rails.error.report(error)
    end
  end
end
