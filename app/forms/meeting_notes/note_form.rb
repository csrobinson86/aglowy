# The edit page of a Life and Ministry note, rendered one piece at a time inside the outline's
# sections (frame life-and-ministry-note.png). Each part's notes are the hand-built Lexxy field
# (meeting_notes/_notes_field), since Primer forms have no rich-text input.
class MeetingNotes::NoteForm < ApplicationForm
  # field: :title (a part's title), :living_part (a Living as Christians part's title, with the
  # _destroy flag the living-parts controller sets on removal) or :actions (Save notes).
  def initialize(field:, label: "Title", placeholder: nil)
    @field = field
    @label = label
    @placeholder = placeholder
  end

  form do |f|
    case @field
    when :title
      f.text_field(name: :title, label: @label, placeholder: @placeholder, full_width: true)
    when :living_part
      f.text_field(name: :title, label: "Part title", placeholder: "As it appears in the workbook", full_width: true,
                   data: { living_parts_target: "title" })
      f.hidden(name: :_destroy, data: { living_parts_target: "destroy" })
    when :actions
      f.submit(name: :submit, label: "Save notes", scheme: :primary)
    end
  end
end
