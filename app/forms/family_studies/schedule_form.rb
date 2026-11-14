# Rendered one section at a time, so the page can give each its box and heading (frame
# schedule-form.png) and wrap Repeat in a Turbo Frame that reloads when the date changes.
class FamilyStudies::ScheduleForm < ApplicationForm
  # section: :topic, :when, :repeat or :actions. Only :actions needs cancel_path.
  # Each section autofocuses its own first invalid input; the browser focuses the first in the page.
  def initialize(section:, cancel_path: nil)
    @section = section
    @cancel_path = cancel_path
  end

  form do |f|
    case @section
    when :topic
      f.text_field(name: :topic, label: "What will you study?", placeholder: "For example, Proverbs 3 or preparing for the memorial",
                   caption: "Everyone in the household sees this. You can change it any time.", full_width: true)
    when :when
      f.group(layout: :horizontal) do |row|
        row.text_field(name: :starts_on, label: "Date", type: :date, required: true,
                       data: { action: "repeat-field#refresh", repeat_field_target: "date" })
        row.text_field(name: :starts_at, label: "Starts", type: :time, required: true, value: time_value(f, :starts_at))
      end
      f.text_field(name: :ends_at, label: "Ends", type: :time, required: true, value: time_value(f, :ends_at))
    when :repeat
      f.select_list(name: :repeat, label: "Repeat", full_width: false, data: { repeat_field_target: "repeat" },
                    caption: "Repeating studies are planned through the end of the service year (August 31) and keep going until you end them.") do |list|
        f.builder.object.repeat_choices.each { |label, value| list.option(label: label, value: value) }
      end
    when :actions
      f.group(layout: :horizontal) do |actions|
        actions.submit(name: :submit, label: "Schedule study", scheme: :primary)
        actions.button(name: :cancel, label: "Cancel", tag: :a, href: @cancel_path, scheme: :link, align_self: :center)
      end
    end
  end

  private
    # A time input takes "19:00", not the "2000-01-01 19:00:00 UTC" Rails would write.
    def time_value(f, name)
      f.builder.object.public_send(name)&.strftime("%H:%M")
    end
end
