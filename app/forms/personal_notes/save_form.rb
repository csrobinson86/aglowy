# The "Save note" button under a note's body.
class PersonalNotes::SaveForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Save note", scheme: :primary)
  end
end
