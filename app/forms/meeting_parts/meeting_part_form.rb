# The Add a part and Edit part dialog (docs/design/meeting-parts.md, Add or edit a part; frame part-new.png), a section
# at a time so Cancel and the submit button sit at the end. Every kind is offered to everyone (Trap 8).
class MeetingParts::MeetingPartForm < ApplicationForm
  # section: :details or :actions. Only :actions needs dialog_id, for Cancel. next_meeting says the date is the
  # household's next midweek meeting.
  def initialize(section:, dialog_id: nil, next_meeting: false)
    @section = section
    @dialog_id = dialog_id
    @next_meeting = next_meeting
  end

  form do |f|
    case @section
    when :details
      f.select_list(name: :kind, label: "Part", full_width: true) do |list|
        MeetingPart::Kind.all.each { list.option(label: it.option_label, value: it.key) }
      end
      f.group(layout: :horizontal) do |row|
        row.text_field(name: :meeting_on, label: "Meeting date", type: :date, required: true, caption: ("Your next midweek meeting." if @next_meeting))
        row.text_field(name: :minutes, label: "Minutes", type: :number, required: true, min: 1, max: 15)
      end
      f.select_list(name: :setting, label: "Setting (optional)", include_blank: "None", full_width: true) do |list|
        MeetingPart::SETTINGS.each { |value, label| list.option(label:, value:) }
      end
      f.text_area(name: :topic, label: "What it's about", required: true, maxlength: 300, full_width: true,
                  caption: "Type it in your own words. Aglowy doesn't copy the workbook.")
      f.group(layout: :horizontal) do |row|
        row.text_field(name: :study_point, label: "Study point (optional)", maxlength: 80)
        row.text_field(name: :assistant, label: "Assistant (optional)", maxlength: 80)
      end
    when :actions
      f.group(layout: :horizontal, justify_content: :flex_end) do |actions|
        actions.button(name: :cancel, label: "Cancel", data: { close_dialog_id: @dialog_id })
        actions.submit(name: :submit, label: f.builder.object.new_record? ? "Add part" : "Save part", scheme: :primary)
      end
    end
  end
end
