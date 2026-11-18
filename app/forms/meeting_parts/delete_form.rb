# The "Delete part" button in a part's delete Dialog.
class MeetingParts::DeleteForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Delete part", scheme: :danger)
  end
end
