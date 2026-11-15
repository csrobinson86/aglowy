# Rendered in two sections, so the page can put its note about steps between the fields and the buttons
# (frame new-goal.png, without the kind picker, which arrives with habits).
class Goals::GoalForm < ApplicationForm
  # section: :fields or :actions. Only :actions needs cancel_path.
  def initialize(section:, cancel_path: nil)
    @section = section
    @cancel_path = cancel_path
  end

  form do |f|
    case @section
    when :fields
      f.text_field(name: :title, label: "Title", required: true, full_width: true)
      f.text_area(name: :body, label: "Why this goal? (optional)", full_width: true,
                  caption: "Shown at the top of the goal so everyone remembers the reason.")
      f.text_field(name: :target_on, label: "Target date", type: :date, required: true, full_width: false)
    when :actions
      f.group(layout: :horizontal) do |actions|
        actions.submit(name: :submit, label: "Create goal", scheme: :primary)
        actions.button(name: :cancel, label: "Cancel", tag: :a, href: @cancel_path, scheme: :link, align_self: :center)
      end
    end
  end
end
