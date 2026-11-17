# The form behind "Turn on for this browser": the push_subscription Stimulus controller fills in what the browser's
# subscription gives it, and whether the page runs from the Home Screen, then submits it (docs/design/notifications.md,
# Settings → Notifications).
class PushSubscriptions::SubscriptionForm < ApplicationForm
  form do |f|
    %i[ endpoint p256dh_key auth_key standalone ].each { f.hidden(name: it) }
  end
end
