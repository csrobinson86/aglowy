# Frames settings-profile.png and account-settings.png, Profile.
class Settings::ProfileForm < ApplicationForm
  form do |f|
    f.text_field(name: :name, label: "Name", required: true, autocomplete: "name", full_width: true)

    # Their times on the calendar are in it, so once they have one it can't be left unset (docs/design/calendar.md, The
    # person's own zone).
    f.select_list(name: :time_zone, label: "Your time zone", include_blank: (f.builder.object.personal_times.none? && "Not set"), full_width: true,
                  caption: "For your own reminders and times. Family studies use each household's time zone.") do |list|
      ActiveSupport::TimeZone.all.each { |zone| list.option(label: zone.to_s, value: zone.name) }
    end

    f.submit(name: :submit, label: "Save profile")
  end
end
