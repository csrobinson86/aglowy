# "Save as a note" on an answer card (docs/design/notes.md, Save an AI answer as a note).
class PersonalStudies::PersonalNoteForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Save as a note", size: :small)
  end
end
