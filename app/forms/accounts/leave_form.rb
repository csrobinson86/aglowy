# The "Leave household" button in account settings' leave Dialog.
class Accounts::LeaveForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Leave household", scheme: :danger)
  end
end
