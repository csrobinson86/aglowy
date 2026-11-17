# Tells whoever sent a household invitation that it's still pending five days on (docs/design/notifications.md,
# Recurring jobs). Daily; safe to run twice.
class Notification::InvitationFollowUpJob < ApplicationJob
  def perform
    Invitation.unaccepted_after_five_days.preloaded.find_each(&:follow_up)
  end
end
