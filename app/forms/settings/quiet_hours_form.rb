# Quiet hours (frame settings-notifications.png): From and Until, every half hour of the day, then Save.
class Settings::QuietHoursForm < ApplicationForm
  # "21:00" => "9:00 PM".
  TIMES = (0...48).map { Time.utc(2000, 1, 1) + it * 30.minutes }.to_h { [ it.strftime("%H:%M"), it.strftime("%-l:%M %p") ] }.freeze

  form do |f|
    f.group(layout: :horizontal) do |group|
      { quiet_hours_start: "From", quiet_hours_end: "Until" }.each do |attribute, label|
        # The attribute is a Time on 2000-01-01, so the option to select is picked here.
        current = @builder.object.public_send(attribute)&.strftime("%H:%M")

        group.select_list(name: attribute, label:) do |list|
          TIMES.each { |value, time| list.option(label: time, value:, selected: value == current) }
        end
      end
    end

    f.submit(name: :submit, label: "Save")
  end
end
