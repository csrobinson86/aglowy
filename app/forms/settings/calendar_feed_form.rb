# The "Reset link" button in Settings → Calendar's confirm Dialog (docs/design/calendar.md, Settings → Calendar).
class Settings::CalendarFeedForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Reset link", scheme: :danger)
  end
end
