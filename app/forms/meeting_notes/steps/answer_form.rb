# "My answer for Bible study" (frame tablet-game-write-answer.png), or "My comment for the Watchtower": the paragraph she
# picked with her family and what she'll say, which she types herself, at the helper's large sizes. From a Get ready
# card, from=prep goes along, so saving goes back to the card (docs/design/meeting-prep.md, Back to her card).
class MeetingNotes::Steps::AnswerForm < ApplicationForm
  def initialize(from_prep: false)
    @from_prep = from_prep
  end

  form do |f|
    f.hidden(name: :from, value: "prep", scope_name_to_model: false) if @from_prep
    f.text_field(name: :paragraph, label: "Paragraph", type: :number, min: 1, max: 999, required: true, size: :large, full_width: false,
                 classes: "meeting-helper__input meeting-helper__input--paragraph", label_arguments: { classes: "meeting-helper__label" })
    f.text_area(name: :body, label: "What I'll say", required: true, maxlength: 500, rows: 3, full_width: true,
                classes: "meeting-helper__input", label_arguments: { classes: "meeting-helper__label" })
    f.submit(name: :save, label: "Save my answer", scheme: :primary, size: :large, classes: "meeting-helper__button meeting-helper__button--done meeting-helper__answer-save") do |button|
      button.with_leading_visual_icon(icon: :check)
    end
  end
end
