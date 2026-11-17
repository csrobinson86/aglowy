# "Your invitation hasn't been accepted": a household invitation still pending five days on, for whoever sent it. It
# opens Members, where it can be sent again, and its email waits for the daily summary. An invitation holds only an
# email address, so that's who it names.
class Notification::Kind::InvitationUnaccepted < Notification::Kind
  include ActionView::Helpers::TextHelper

  def icon = :mail
  def color = :gray
  def email = :summary

  def title
    "Your invitation hasn't been accepted"
  end

  def body
    "#{subject.email} was invited #{pluralize(days_ago, "day")} ago. Send it again?"
  end

  def target_path
    household_members_path(household_id:)
  end

  private
    def days_ago
      ((Time.current - subject.created_at) / 1.day).floor
    end
end
