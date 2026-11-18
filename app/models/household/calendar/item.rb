# One thing on the calendar, with its times in the household's zone. kind picks the color (.calendar-item--<kind>);
# source is what it comes from, a Household::Meeting, a FamilyStudy::Session (unsaved past the generator's horizon), a
# Household::Event, a MeetingPart or a PersonalTime::Occurrence, so the page can link to it; for another member's shared time it's the
# person, so nothing about the time itself reaches the page. An all-day item runs from the midnight it starts to the midnight after
# its last day.
Household::Calendar::Item = Data.define(:kind, :title, :subtitle, :starts_at, :ends_at, :all_day, :source) do
  def self.from_meeting(meeting)
    new(kind: "meeting", title: meeting.title, subtitle: nil, starts_at: meeting.starts_at, ends_at: meeting.ends_at, all_day: false, source: meeting)
  end

  def self.from_session(session)
    new(kind: "study", title: "Family study", subtitle: session.topic.presence || "Topic not chosen yet",
        starts_at: session.local_scheduled_at, ends_at: session.local_ends_at, all_day: false, source: session)
  end

  def self.from_event(event, occurrence)
    new(kind: event.kind, title: event.title, subtitle: event.location.presence, starts_at: occurrence.begin, ends_at: occurrence.end,
        all_day: event.all_day?, source: event)
  end

  # On its meeting day, at the midweek meeting's own start and end when that's the household's midweek day, otherwise all
  # day. "Your part: Talk" for the viewer's, "Daniel: Talk" for one shared here; only its kind and minutes, never what
  # it's about, its preparation or its counsel (docs/design/meeting-parts.md, Trap 3).
  def self.from_meeting_part(part, household:, viewer:)
    label = part.kind_details.label
    title = part.user_id == viewer.id ? "Your part: #{label}" : "#{part.user.first_name}: #{label}"
    meeting = household.meetings_between(part.meeting_on..part.meeting_on).find { it.kind == "midweek" }
    starts_at, ends_at = meeting ? [ meeting.starts_at, meeting.ends_at ] : [ part.meeting_on, part.meeting_on.next_day ].map { it.in_time_zone(household.time_zone) }
    new(kind: "meeting_part", title:, subtitle: "#{part.minutes} min", starts_at:, ends_at:, all_day: meeting.nil?, source: part)
  end

  # The viewer's own time, converted to the household's zone. Its subtitle names what it opens: a study or a note, or for
  # meeting prep the note for that week's next meeting.
  def self.from_time(occurrence, household:)
    zone = household.time_zone
    new(kind: "my_time", title: occurrence.title, subtitle: occurrence.opens_title(household), starts_at: occurrence.starts_at.in_time_zone(zone),
        ends_at: occurrence.ends_at.in_time_zone(zone), all_day: false, source: occurrence)
  end

  # Another member's time, shared with the household: its title and when it is, and "<First name>'s time" under it.
  # Never its done mark or what it opens, and never a link (Trap 3).
  def self.from_shared_time(occurrence, household:)
    zone = household.time_zone
    new(kind: "shared", title: occurrence.title, subtitle: "#{occurrence.personal_time.user.first_name}'s time",
        starts_at: occurrence.starts_at.in_time_zone(zone), ends_at: occurrence.ends_at.in_time_zone(zone), all_day: false,
        source: occurrence.personal_time.user)
  end

  def my_time?
    kind == "my_time"
  end

  def shared?
    kind == "shared"
  end

  def meeting?
    kind == "meeting"
  end

  def meeting_part?
    kind == "meeting_part"
  end

  def event?
    source.is_a?(Household::Event)
  end

  # The days it falls on: a timed item only on the day it starts.
  def dates
    all_day ? starts_at.to_date..ends_at.to_date.yesterday : starts_at.to_date..starts_at.to_date
  end

  def on?(date)
    dates.cover?(date)
  end

  # Where an all-day item sits among the days shown: its first column (from 1) and how many columns it spans.
  def columns_in(days)
    first, last = [ dates.first, days.first ].max, [ dates.last, days.last ].min
    [ (first - days.first).to_i + 1, (last - first).to_i + 1 ]
  end
end
