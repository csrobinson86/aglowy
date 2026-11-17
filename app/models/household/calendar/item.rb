# One thing on the calendar, with its times in the household's zone. kind picks the color (.calendar-item--<kind>);
# source is what it comes from, a Household::Meeting, a FamilyStudy::Session (unsaved past the generator's horizon) or a
# Household::Event, so the page can link to it. An all-day item runs from the midnight it starts to the midnight after
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

  def meeting?
    kind == "meeting"
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
