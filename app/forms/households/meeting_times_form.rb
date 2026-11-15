# Household settings, Meetings (frames household-settings-head.png and household-settings-adult.png). Primer forms have
# no headings, so each label names its meeting. Days are Ruby's wday, listed from Monday.
class Households::MeetingTimesForm < ApplicationForm
  DAYS = Date::DAYNAMES.each_with_index.to_a.rotate(1).freeze

  form do |f|
    Household::MEETING_KINDS.each do |kind|
      f.group(layout: :horizontal) do |group|
        group.select_list(name: :"#{kind}_meeting_wday", label: "#{kind.humanize} day", prompt: "Choose a day") do |list|
          DAYS.each { |day, wday| list.option(label: day, value: wday) }
        end
        group.text_field(name: :"#{kind}_meeting_time", label: "#{kind.humanize} starts at", type: :time,
                         value: hours_and_minutes(:"#{kind}_meeting_time"))
      end
    end

    f.submit(name: :submit, label: "Save")
  end

  private
    # A time field takes "19:00"; the attribute is a Time on 2000-01-01.
    def hours_and_minutes(attribute)
      @builder.object.public_send(attribute)&.strftime("%H:%M")
    end
end
