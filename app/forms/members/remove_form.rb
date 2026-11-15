# The "Remove" button in household settings' remove-member Dialog.
class Members::RemoveForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Remove", scheme: :danger)
  end
end
