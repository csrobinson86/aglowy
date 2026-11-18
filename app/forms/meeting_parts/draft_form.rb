# Asking the AI for an outline of a part (frame part-prepare.png). Outline only for now: "What would help?" comes with
# sample wording. disabled: true is Limit reached.
class MeetingParts::DraftForm < ApplicationForm
  def initialize(disabled: false)
    @disabled = disabled
  end

  form do |f|
    f.text_area(name: :request, label: "Anything it should know? (optional)", character_limit: MeetingPart::Draft::REQUEST_MAX, rows: 3, full_width: true,
                disabled: @disabled, caption: "Only the part's details above and what you type here are sent. Never your preparation, names or anything else.")
    f.submit(name: :submit, label: "Draft outline", scheme: :primary, block: true, disabled: @disabled)
  end
end
