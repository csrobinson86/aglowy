# Under a draft (frames part-ai-outline.png, part-ai-wording.png): Ask for a change, where each chip fills the box and
# "Change it" asks for a new draft of the same kind that revises the one shown; or, with wording: true, "Write sample
# wording" under an outline, a new wording draft that revises it (docs/design/meeting-parts.md, How a request runs).
class MeetingParts::ChangeForm < ApplicationForm
  CHIPS = [ "Shorter opening", "Simpler words", "A different scripture" ].freeze

  def initialize(wording: false)
    @wording = wording
  end

  form do |f|
    f.hidden(name: :kind)
    f.hidden(name: :revises_id)

    if @wording
      f.submit(name: :submit, label: "Write sample wording")
    else
      # Plain buttons: the ai-panel Stimulus controller fills the box instead of submitting.
      f.group(layout: :horizontal, classes: "flex-wrap gap-2", role: "group", aria: { label: "Changes to start from" }) do |chips|
        CHIPS.each_with_index do |label, index|
          chips.button(name: :"chip_#{index}", label: label, size: :small, data: { action: "ai-panel#fill", ai_panel_text_param: label })
        end
      end
      f.group(layout: :horizontal) do |change|
        change.text_field(name: :request, label: "Your change", visually_hide_label: true, maxlength: MeetingPart::Draft::CHANGE_MAX, full_width: true,
                          placeholder: "Add an illustration a child would get", data: { ai_panel_target: "prompt" },
                          caption: "Sends the part's details, this draft and your change. Never your preparation.")
        change.submit(name: :submit, label: "Change it")
      end
    end
  end
end
