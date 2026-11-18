# "My notes for this meeting" on a part: finds or starts the person's own midweek note for the part's week.
class MeetingParts::MeetingNoteForm < ApplicationForm
  def initialize(week_of:)
    @week_of = week_of
  end

  form do |f|
    f.hidden(name: :kind, value: "midweek")
    f.hidden(name: :week_of, value: @week_of.iso8601)
    f.submit(name: :start, label: "My notes for this meeting", scheme: :link)
  end
end
