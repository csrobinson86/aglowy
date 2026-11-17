# Settings → Household (docs/design/settings.md).
class Settings::HouseholdForm < ApplicationForm
  form do |f|
    f.text_field(name: :name, label: "Name", required: true, full_width: true)

    f.select_list(name: :time_zone, label: "Time zone", full_width: true,
                  caption: "Family studies happen at their local time here. Changing it keeps each study at the same local time.") do |list|
      ActiveSupport::TimeZone.all.each { |zone| list.option(label: zone.to_s, value: zone.name) }
    end

    f.submit(name: :submit, label: "Save")
  end
end
