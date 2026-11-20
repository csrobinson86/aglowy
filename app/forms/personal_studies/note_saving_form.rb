# "Save to note" on an answer card (docs/design/personal-study.md, Save to note).
class PersonalStudies::NoteSavingForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Save to note", size: :small)
  end
end
