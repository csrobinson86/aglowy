# The edit page of a meeting note, rendered one piece at a time inside the outline's sections
# (frames life-and-ministry-note.png, weekend-note.png). Each part's notes are the hand-built Lexxy
# field (meeting_notes/_notes_field), since Primer forms have no rich-text input.
class MeetingNotes::NoteForm < ApplicationForm
  # field: :title or :speaker (a part's text fields, labelled from its outline Field), :repeating_title
  # (a repeating part's title, with the _destroy flag the living-parts controller sets on removal),
  # :scripture and :insight (a gem's two fields, side by side in meeting_notes/_gem, with the _destroy
  # flag the gems controller sets) or :actions (Save notes).
  def initialize(field:, label: nil, placeholder: nil)
    @field = field
    @label = label
    @placeholder = placeholder
  end

  form do |f|
    case @field
    when :title, :speaker
      f.text_field(name: @field, label: @label, placeholder: @placeholder, full_width: true)
    when :repeating_title
      f.text_field(name: :title, label: @label, placeholder: @placeholder, full_width: true,
                   data: { living_parts_target: "title" })
      f.hidden(name: :_destroy, data: { living_parts_target: "destroy" })
    when :scripture
      # Only the model's message, so the field reads "Use a reference like Isaiah 41:10.", not "Scripture Use a …".
      f.text_field(name: :scripture, label: "Scripture", full_width: true,
                   validation_message: f.builder.object.errors[:scripture].first,
                   data: { gems_target: "scripture", action: "gems#name" })
    when :insight
      f.text_area(name: :insight, label: "What I found", full_width: true)
      f.hidden(name: :_destroy, data: { gems_target: "destroy" })
    when :actions
      f.submit(name: :submit, label: "Save notes", scheme: :primary)
    end
  end
end
