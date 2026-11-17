# The household event dialog (docs/design/calendar.md, The household event dialog), a section at a time so Repeats can
# sit in its own Turbo Frame. All day switches between Starts and Ends dates and a Date with Starts and Ends times: the
# calendar-event controller hides one group and disables its inputs, so only the other is sent.
class Calendar::EventForm < ApplicationForm
  # section: :when, :repeat, :details or :actions. Only :actions needs dialog_id, for Cancel.
  def initialize(section:, dialog_id: nil)
    @section = section
    @dialog_id = dialog_id
  end

  form do |f|
    event = f.builder.object

    case @section
    when :when
      f.select_list(name: :kind, label: "Kind", data: { calendar_event_target: "kind", action: "calendar-event#kindChanged" }) do |list|
        Household::Event::KINDS.each { |value, label| list.option(label:, value:) }
      end
      f.text_field(name: :title, label: "Title", required: true, maxlength: 80, full_width: true, data: { calendar_event_target: "title" })
      f.check_box(name: :all_day, label: "All day", data: { calendar_event_target: "allDay", action: "calendar-event#allDayChanged" })
      f.group(layout: :horizontal, hidden: !event.all_day, data: { calendar_event_target: "allDayFields" }) do |row|
        row.text_field(name: :starts_on, label: "Starts", type: :date, required: true, disabled: !event.all_day,
                       data: { calendar_event_target: "startsOn", action: "calendar-event#dateChanged" })
        row.text_field(name: :ends_on, label: "Ends", type: :date, required: true, disabled: !event.all_day,
                       data: { calendar_event_target: "endsOn", action: "calendar-event#endsChanged" })
      end
      f.group(layout: :horizontal, hidden: event.all_day, data: { calendar_event_target: "timedFields" }) do |row|
        row.text_field(name: :starts_on, id: "household_event_date", label: "Date", type: :date, required: true, disabled: event.all_day,
                       data: { calendar_event_target: "date", action: "calendar-event#dateChanged" })
        row.text_field(name: :starts_at, label: "Starts", type: :time, required: true, disabled: event.all_day, value: event.starts_at&.strftime("%H:%M"))
        row.text_field(name: :ends_at, label: "Ends", type: :time, required: true, disabled: event.all_day, value: event.ends_at&.strftime("%H:%M"))
      end
    when :repeat
      f.select_list(name: :repeat, label: "Repeats", data: { calendar_event_target: "repeat" }) do |list|
        event.repeat_choices.each { |label, value| list.option(label:, value:) }
      end
    when :details
      f.text_field(name: :location, label: "Where (optional)", maxlength: 120, full_width: true)
      f.text_area(name: :note, label: "Note (optional)", maxlength: 500, full_width: true)
    when :actions
      f.group(layout: :horizontal, justify_content: :flex_end) do |actions|
        actions.button(name: :cancel, label: "Cancel", data: { close_dialog_id: @dialog_id })
        actions.submit(name: :submit, label: event.new_record? ? "Add event" : "Save event", scheme: :primary)
      end
    end
  end
end
