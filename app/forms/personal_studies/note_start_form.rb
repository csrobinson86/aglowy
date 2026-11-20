# "Start a note" in the study's note panel when the study has none (docs/design/personal-study.md, The study page).
class PersonalStudies::NoteStartForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Start a note", size: :small)
  end
end
