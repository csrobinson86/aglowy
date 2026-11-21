# "All done" on the drawing page (frame tablet-draw.png). The canvas's PNG goes into the hand-built file input beside
# it, inside the same primer_form_with: Primer forms have no file input (CLAUDE.md, Forms, third approved exception).
# From Get ready's Draw it!, from=prep goes along, so saving goes back to the card.
class MeetingNotes::Steps::DrawingForm < ApplicationForm
  def initialize(from_prep: false)
    @from_prep = from_prep
  end

  form do |f|
    f.hidden(name: :from, value: "prep") if @from_prep
    f.submit(name: :done, label: "All done", scheme: :primary, size: :large, classes: "meeting-helper__button meeting-helper__button--done",
             data: { meeting_helper__drawing_target: "done" }) do |button|
      button.with_leading_visual_icon(icon: :check)
    end
  end
end
