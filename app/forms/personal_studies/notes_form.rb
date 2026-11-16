# The "Save notes" button under My notes. The editor itself is the hand-built meeting_notes/notes_field partial,
# since Primer forms have no rich-text input (CLAUDE.md, Forms).
class PersonalStudies::NotesForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Save notes", scheme: :primary)
  end
end
