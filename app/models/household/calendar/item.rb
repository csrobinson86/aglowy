# One thing on the calendar, with its times in the household's zone. kind picks the color (.calendar-item--<kind>);
# source is what it comes from, a Household::Meeting or a FamilyStudy::Session (unsaved past the generator's horizon),
# so the page can link to it.
Household::Calendar::Item = Data.define(:kind, :title, :subtitle, :starts_at, :ends_at, :source) do
  def self.from_meeting(meeting)
    new(kind: "meeting", title: meeting.title, subtitle: nil, starts_at: meeting.starts_at, ends_at: meeting.ends_at, source: meeting)
  end

  def self.from_session(session)
    new(kind: "study", title: "Family study", subtitle: session.topic.presence || "Topic not chosen yet",
        starts_at: session.local_scheduled_at, ends_at: session.local_ends_at, source: session)
  end

  def meeting?
    kind == "meeting"
  end

  def on?(date)
    starts_at.to_date == date
  end
end
