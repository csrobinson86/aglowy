# The "Move" button in a note's Move to collection Dialog on a phone, under the note's version (PersonalNotes::VersionForm)
# and its collection (PersonalNotes::CollectionForm), so the move saves through update's version check.
class PersonalNotes::MoveForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Move", scheme: :primary)
  end
end
