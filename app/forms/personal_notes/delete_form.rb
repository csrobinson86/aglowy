# The "Delete note" button in a note's delete Dialog.
class PersonalNotes::DeleteForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Delete note", scheme: :danger)
  end
end
