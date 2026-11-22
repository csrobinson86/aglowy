# Adding a step at the foot of the steps list, and editing one in place (docs/design/goals.md, Pages, "Steps").
# Rendered in two sections, so the edit form can say which ticks a change of people clears before its buttons.
# For lists the household's active members; ticking no one makes the step for everyone.
class Goals::Steps::StepForm < ApplicationForm
  # section: :fields or :actions. members: who the step can be for (none on a personal goal).
  # checked_ids: the people ticked in a submission that came back with an error, instead of the step's own.
  def initialize(section:, members: [], editing: false, checked_ids: nil)
    @section = section
    @members = members
    @editing = editing
    @checked_ids = checked_ids
  end

  form do |f|
    case @section
    when :fields
      f.text_field(name: :title, label: @editing ? "Title" : "New step", required: true, full_width: true,
                   placeholder: ("Something small that moves the goal forward" unless @editing))
      f.group(layout: :horizontal) do |row|
        if @members.any?
          row.check_box_group(name: :assignee_ids, label: "For", caption: "Tick no one and it's for everyone.",
                              validation_message: ("Choose people in this household" if step.errors[:assignments].any?)) do |group|
            @members.each { group.check_box(value: it.id, label: it.name, checked: it.id.in?(assigned_ids)) }
          end
        end
        row.text_field(name: :due_on, label: "Due (optional)", type: :date, full_width: false)
      end
      f.hidden(name: :lock_version) if @editing
    when :actions
      f.group(layout: :horizontal) do |actions|
        actions.submit(name: :submit, label: @editing ? "Save" : "Add step", scheme: @editing ? :primary : :default)
        if @editing
          actions.button(name: :cancel, label: "Cancel", scheme: :invisible, data: { action: "goal-step#cancel" })
        else
          # On a phone the add-step form opens from "+ Add step", and Cancel hides it again (docs/design/phone.md, rule 7).
          actions.button(name: :cancel, label: "Cancel", display: [ nil, nil, :none ], data: { action: "add-row#close" })
        end
      end
    end
  end

  private
    def step
      @builder.object
    end

    # From loaded assignments, so a page of steps asks no query per form.
    def assigned_ids
      @assigned_ids ||= @checked_ids || step.assignments.map(&:user_id)
    end
end
