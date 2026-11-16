# "Save to notes" on an answer card (docs/design/personal-study.md, Save to notes).
class PersonalStudies::NoteSavingForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Save to notes", size: :small)
  end
end
