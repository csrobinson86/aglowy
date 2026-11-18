# Asking the AI for help with a part (frame part-prepare.png): "What would help?", An outline or Sample wording, which
# names the button, and anything it should know. disabled: true is Limit reached.
class MeetingParts::DraftForm < ApplicationForm
  # Each kind's choice, and what the button reads once it's chosen.
  KINDS = { "outline" => [ "An outline", "Draft outline" ], "wording" => [ "Sample wording", "Draft wording" ] }.freeze

  def initialize(kind: "outline", disabled: false)
    @kind = kind
    @disabled = disabled
  end

  form do |f|
    f.radio_button_group(name: :kind, label: "What would help?") do |kinds|
      KINDS.each do |value, (label, button)|
        kinds.radio_button(value: value, label: label, disabled: @disabled, data: { action: "ai-panel#kindChosen", ai_panel_label_param: button })
      end
    end
    f.text_area(name: :request, label: "Anything it should know? (optional)", character_limit: MeetingPart::Draft::REQUEST_MAX, rows: 3, full_width: true,
                disabled: @disabled, caption: "Only the part's details above and what you type here are sent. Never your preparation, names or anything else.")
    f.submit(name: :submit, label: KINDS.fetch(@kind, KINDS["outline"]).last, scheme: :primary, block: true, disabled: @disabled, data: { ai_panel_target: "submit" })
  end
end
