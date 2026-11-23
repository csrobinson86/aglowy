# "Keep in Notes", under a week's study guide (docs/design/study-guide.md, Pages and routes). The week is in the URL.
class StudyGuides::NoteForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Keep in Notes")
  end
end
