# Tells whoever sent a household invitation that it's still pending five days on (docs/design/notifications.md,
# Recurring jobs). Daily; safe to run twice. One that fails is reported and the rest go on.
class Notification::InvitationFollowUpJob < ApplicationJob
  def perform
    each_reporting_failures(Invitation.unaccepted_after_five_days.preloaded, &:follow_up)
  end
end
