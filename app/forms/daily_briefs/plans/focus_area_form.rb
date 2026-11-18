# The focus area dialog on Your plan (docs/design/daily-brief.md, Your plan): its name, what it gives and its
# scriptures, then Cancel and Add or Save. The name and what it gives are sent to the AI as typed, so both say so and
# ask for no names (Trap 2). A new one carries its kind, from the library entry it was filled in from or a role. Linked
# goal offers the person's own active goals; nothing about a goal is sent (the story, #310).
class DailyBriefs::Plans::FocusAreaForm < ApplicationForm
  SENT_TO_AI = "Sent to the AI as you type it. Leave out names."

  def initialize(dialog_id:)
    @dialog_id = dialog_id
  end

  form do |f|
    focus_area = f.builder.object

    f.hidden(name: :kind) if focus_area.new_record?
    f.text_field(name: :name, label: "Name", caption: SENT_TO_AI, required: true, maxlength: 60, full_width: true)
    f.text_area(name: :gives, label: "What it gives", caption: SENT_TO_AI, required: true, maxlength: 200, full_width: true)
    f.text_field(name: :scriptures, label: "Scriptures (optional)", maxlength: 120, full_width: true,
                 caption: "Separate references with a semicolon: Proverbs 4:23; Colossians 3:23.")
    f.select_list(name: :goal_id, label: "Linked goal", include_blank: "None", full_width: true,
                  caption: "One of your own goals. The brief shows its next step here; it isn't sent to the AI.") do |list|
      focus_area.plan.linkable_goals.each { |goal| list.option(label: goal.title, value: goal.id) }
    end
    f.group(layout: :horizontal, justify_content: :flex_end) do |actions|
      actions.button(name: :cancel, label: "Cancel", data: { close_dialog_id: @dialog_id })
      actions.submit(name: :submit, label: focus_area.new_record? ? "Add focus area" : "Save focus area", scheme: :primary)
    end
  end
end
