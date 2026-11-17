# Each household where it's the 8 AM hour asks its heads for the topic of any session three days ahead that has none
# (docs/design/notifications.md, Recurring jobs). Hourly, so every zone has its 8 AM; safe to run twice.
class Notification::StudyTopicJob < ApplicationJob
  def perform
    Household.at_local_hour(8).find_each(&:ask_heads_for_study_topics)
  end
end
