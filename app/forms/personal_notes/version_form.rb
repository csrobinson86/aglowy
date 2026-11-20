# The edit form's hidden field for the version check (docs/design/notes.md, A note: the version check): base, the
# note's version when the form was rendered.
class PersonalNotes::VersionForm < ApplicationForm
  form do |f|
    f.hidden(name: :base)
  end
end
