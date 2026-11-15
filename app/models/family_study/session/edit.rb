# The Edit a session form: Topic, Date and Starts, for this session only (scheduling rule 7).
# A new date or time reschedules the session; a topic alone leaves it on the schedule.
class FamilyStudy::Session::Edit
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_reader :session

  attribute :topic, :string
  attribute :starts_on, :date
  attribute :starts_at, :time

  validates :starts_on, :starts_at, presence: true

  # Starts from what the session has, in the household's zone, until the form sends its own values.
  def initialize(session, **attributes)
    @session = session
    local = session.local_scheduled_at
    super(topic: session.topic, starts_on: local.to_date, starts_at: local.strftime("%H:%M"), **attributes)
  end

  def save
    return false unless valid?

    # The household's lock before the session's row, in the order a time zone change takes them, so the two can't deadlock.
    session.transaction do
      session.family_study.household.lock!
      session.update!(topic: topic.presence)
      session.reschedule(on: starts_on, at: starts_at)
    end
    true
  end
end
