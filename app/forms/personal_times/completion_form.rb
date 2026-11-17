# The done box on one day of a personal time (docs/design/calendar.md, My time's done box): one check box, sent as soon
# as it changes. Unticked, its form posts the day as on; ticked, its form deletes completions/<day>, so it sends nothing.
class PersonalTimes::CompletionForm < ApplicationForm
  def initialize(occurrence:)
    @occurrence = occurrence
  end

  form do |f|
    f.hidden(name: :on, value: @occurrence.on.iso8601) unless @occurrence.done?
    f.check_box(name: :done, label: "Done: #{@occurrence.title}, #{@occurrence.on.strftime("%A")}", visually_hide_label: true,
                checked: @occurrence.done?, id: "personal_time_#{@occurrence.personal_time.id}_#{@occurrence.on.iso8601}_done")
  end
end
