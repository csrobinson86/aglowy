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

# Maria's own times (docs/design/calendar.md, Elsewhere): daily Bible reading at 6:30 AM, done yesterday and today;
# personal study on Tuesdays at 8:30 PM, opening a study of her own; and meeting prep on Wednesday evening, the day before
# the Thursday midweek meeting. Lucia, the child with a login, reads a Bible story at 7:30 PM every day. Each starts a
# week back, so the days before today show; saving the first settles the person's zone to the Riveras'. Titles are
# encrypted, so each is found by its kind.
lucia = seeded_person("lucia.rivera")
listening = seed_personal_study(maria, title: "Being a good listener", notes: "<p>Jas 1:19: quick to listen, slow to speak.</p>")

def seed_personal_time(user, household, kind:, **attributes)
  user.personal_times.find_by(kind:) || user.personal_times.new(starts_on: household.today - 7).tap do |time|
    time.plan({ kind:, duration_minutes: 30, **attributes }, household:) || raise(ActiveRecord::RecordInvalid, time)
  end
end

reading = seed_personal_time(maria, rivera, kind: "bible_reading", title: "Daily Bible reading", wdays: [ 0, 1, 2, 3, 4, 5, 6 ], time_of_day: "06:30")
[ reading.today - 1, reading.today ].each { reading.complete(on: it) }
seed_personal_time(maria, rivera, kind: "personal_study", title: "Personal study", wdays: [ 2 ], time_of_day: "20:30", duration_minutes: 60, opens: listening)
seed_personal_time(maria, rivera, kind: "meeting_prep", title: "Meeting prep", wdays: [ 3 ], time_of_day: "19:00", duration_minutes: 45)
seed_personal_time(lucia, rivera, kind: "bible_reading", title: "Read a Bible story", wdays: [ 0, 1, 2, 3, 4, 5, 6 ], time_of_day: "19:30", duration_minutes: 15)

# Lucia shares her times with the Riveras, so Maria sees "Lucia's time" on the calendar (docs/design/calendar.md,
# Membership::TimeSharing).
rivera.memberships.find_by!(user: lucia).share_times
