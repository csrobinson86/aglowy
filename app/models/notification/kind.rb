# What each kind of notification says, shows and opens, and when its email goes (docs/design/notifications.md, The kinds).
# Each kind is a subclass, given the notification it describes. Later kinds join the list in their own stories.
class Notification::Kind
  include Rails.application.routes.url_helpers

  def self.kinds
    { "weekly_preview" => WeeklyPreview, "study_topic_needed" => StudyTopicNeeded, "shared_with_you" => SharedWithYou,
      "invitation_unaccepted" => InvitationUnaccepted }
  end

  def self.for(notification)
    kinds.fetch(notification.kind).new(notification)
  end

  # Every kind, describing no notification: its name, its label and description in Settings → Notifications, who is
  # offered it, and when its email goes.
  def self.all
    kinds.values.map { it.new(nil) }
  end

  # The names of the kinds whose email waits for the daily summary.
  def self.summary_names
    all.select(&:summary?).map(&:name)
  end

  attr_reader :notification

  delegate :subject, :actor, :household_id, to: :notification

  def initialize(notification)
    @notification = notification
  end

  def name
    self.class.kinds.key(self.class)
  end

  def right_away?
    email == :right_away
  end

  def summary?
    email == :summary
  end

  # The words beside its Email box.
  def email_caption
    right_away? ? "Right away" : "In your daily summary"
  end

  # Everyone gets the weekly preview and shares; the other kinds say who they're for.
  def offered_to?(_user)
    true
  end
end
