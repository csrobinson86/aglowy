# "Start notes" on a This week card: finds or creates the person's note for that meeting and week.
class MeetingNotes::StartForm < ApplicationForm
  def initialize(meeting_note:)
    @meeting_note = meeting_note
  end

  form do |f|
    f.hidden(name: :kind, value: @meeting_note.kind)
    f.hidden(name: :week_of, value: @meeting_note.week_of.iso8601)
    f.submit(name: :start, label: "Start notes", scheme: :primary) do |button|
      button.with_leading_visual_icon(icon: :plus)
    end
  end
end
