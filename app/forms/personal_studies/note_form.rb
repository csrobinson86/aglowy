# The study's note edited in place (docs/design/personal-study.md, The study page: Study note): base, the note's version
# when the form was rendered, for the version check. The body's editor follows it, the hand-built
# meeting_notes/notes_field partial since Primer forms have no rich-text input (CLAUDE.md, Forms), then PersonalNotes::SaveForm.
class PersonalStudies::NoteForm < ApplicationForm
  form do |f|
    f.hidden(name: :base)
  end
end
