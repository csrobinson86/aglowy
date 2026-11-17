# VAPID keys for Web Push (docs/design/notifications.md, Push): web_push.public_key, private_key and subject in
# credentials, or VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY and VAPID_SUBJECT in the environment. Generate a pair with
# `bin/rails runner 'k = WebPush.generate_key; puts k.public_key, k.private_key'`; the subject is a "mailto:" address.
# The public key goes into Settings → Notifications for the browser; without keys, nothing can turn push on.
Rails.application.config.x.web_push = {
  public_key: Rails.application.credentials.dig(:web_push, :public_key) || ENV["VAPID_PUBLIC_KEY"],
  private_key: Rails.application.credentials.dig(:web_push, :private_key) || ENV["VAPID_PRIVATE_KEY"],
  subject: Rails.application.credentials.dig(:web_push, :subject) || ENV["VAPID_SUBJECT"]
}
