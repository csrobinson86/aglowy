# The Rivera household's events (docs/design/calendar.md, Elsewhere): the circuit overseer's visit this week, Tuesday
# to Sunday; a circuit assembly the Saturday after next; field service every Saturday at 9:30 AM; and Kingdom Hall
# cleaning this Saturday at 1 PM.
rivera, maria = seeded_household("The Rivera Family", head: "rivera@example.com"), seeded_person("rivera@example.com")
monday = rivera.today.beginning_of_week(:monday)

[
  { kind: "co_visit", title: "Circuit overseer's visit", starts_on: monday + 1, days: 6, location: "Kingdom Hall" },
  { kind: "circuit_assembly", title: "Circuit assembly", starts_on: monday + 12, location: "Assembly Hall", note: "Bring lunch. Program starts at 9:40." },
  { kind: "field_service", title: "Field service", starts_on: monday + 5, time_of_day: "09:30", duration_minutes: 90, frequency: "weekly",
    location: "Meet at the Kingdom Hall" },
  { kind: "other", title: "Kingdom Hall cleaning", starts_on: monday + 5, time_of_day: "13:00", duration_minutes: 120 }
].each do |event|
  rivera.events.exists?(title: event[:title]) || rivera.events.create!(created_by: maria, **event)
end
