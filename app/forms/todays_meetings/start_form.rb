# A button on Today's meeting: "Start my notes" for the current or next meeting, or, before any times are set,
# Midweek meeting and Weekend meeting for this week. Either finds or starts the person's note.
class TodaysMeetings::StartForm < ApplicationForm
  def initialize(kind:, week_of:, label:, **button)
    @kind = kind
    @week_of = week_of
    @label = label
    @button = button
  end

  form do |f|
    f.hidden(name: :kind, value: @kind)
    f.hidden(name: :week_of, value: @week_of.iso8601)
    f.submit(name: :start, label: @label, **@button)
  end
end
