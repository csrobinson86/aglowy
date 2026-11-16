# A note's title, on the New note page and a note's page. The color picker follows it, then the collection
# (PersonalNotes::CollectionForm), then the body's editor, the hand-built meeting_notes/notes_field partial, since
# Primer forms have no rich-text input or swatches (CLAUDE.md, Forms).
class PersonalNotes::NoteForm < ApplicationForm
  form do |f|
    f.text_field(name: :title, label: "Title", required: true, full_width: true, maxlength: 120, size: :large)
  end
end
