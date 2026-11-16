# Describing a study for an AI draft (frame ai-describe.png), rendered one section at a time so the panel can put the
# starter ideas' heading and the privacy note between them. disabled: true is Limit reached (frame ai-limit.png),
# which shows only the prompt and the actions.
class FamilyStudies::DraftForm < ApplicationForm
  # Each starter idea's button, and what it puts in the box for the person to finish.
  IDEAS = {
    "A Bible chapter" => "A Bible chapter to read and talk about together: ",
    "This week's meeting" => "Preparing together for this week's meeting: ",
    "Something we're facing" => "Something our family is facing: "
  }.freeze

  # section: :prompt, :ideas, :options or :actions.
  def initialize(section:, disabled: false)
    @section = section
    @disabled = disabled
  end

  form do |f|
    case @section
    when :prompt
      f.text_area(name: :prompt, label: "What should the study be about?", required: true, character_limit: 500, rows: 4, full_width: true,
                  disabled: @disabled, data: { ai_panel_target: "prompt" })
    when :ideas
      # Plain buttons: the ai-panel Stimulus controller fills the box instead of submitting.
      f.group(layout: :horizontal, classes: "flex-wrap gap-2", role: "group", aria: { labelledby: "ai-panel-ideas" }) do |ideas|
        IDEAS.each_with_index do |(label, text), index|
          ideas.button(name: :"idea_#{index}", label: label, size: :small, data: { action: "ai-panel#fill", ai_panel_text_param: text })
        end
      end
    when :options
      f.select_list(name: :length_minutes, label: "Length", full_width: false) do |list|
        FamilyStudy::Draft::LENGTHS.each { |minutes| list.option(label: "About #{minutes} minutes", value: minutes) }
      end
      f.check_box(name: :young_children, label: "Keep it easy for young children to follow")
    when :actions
      f.group(layout: :horizontal) do |actions|
        actions.submit(name: :submit, label: "Draft outline", scheme: :primary, disabled: @disabled)
        actions.button(name: :cancel, label: @disabled ? "Close" : "Cancel", data: { action: "ai-panel#close" })
      end
    end
  end
end
