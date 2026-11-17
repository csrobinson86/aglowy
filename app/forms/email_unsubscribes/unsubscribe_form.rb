# The one button on the "Turn off this email" page (docs/design/notifications.md, Emails).
class EmailUnsubscribes::UnsubscribeForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Turn off this email", scheme: :primary)
  end
end
