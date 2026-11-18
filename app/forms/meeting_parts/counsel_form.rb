# After the meeting, under a part's preparation, and the one Save for both (docs/design/meeting-parts.md, A part). The
# preparation's editor is the hand-built meeting_notes/notes_field partial, since Primer forms have no rich-text input.
class MeetingParts::CounselForm < ApplicationForm
  form do |f|
    f.text_area(name: :counsel, label: "Counsel, and what to work on next", maxlength: 2000, full_width: true, rows: 4,
                caption: "Only you see this, even when the part is shared.")
    f.submit(name: :submit, label: "Save", scheme: :primary)
  end
end
