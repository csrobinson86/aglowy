# The "Leave household" button in My households' leave Dialog, in Settings and on /account.
class Settings::LeaveForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Leave household", scheme: :danger)
  end
end
