# What each kind of notification says, shows and opens, and when its email goes (docs/design/notifications.md, The kinds).
# Each kind is a subclass, given the notification it describes. Later kinds join the list in their own stories.
class Notification::Kind
  include Rails.application.routes.url_helpers

  def self.for(notification)
    { "weekly_preview" => WeeklyPreview, "study_topic_needed" => StudyTopicNeeded, "shared_with_you" => SharedWithYou,
      "invitation_unaccepted" => InvitationUnaccepted }.fetch(notification.kind).new(notification)
  end

  attr_reader :notification

  delegate :subject, :actor, :household_id, to: :notification

  def initialize(notification)
    @notification = notification
  end
end
