module MeetingPartsHelper
  # "Thursday, December 3 · Midweek meeting · in 16 days", under a part's heading (docs/design/meeting-parts.md, A part).
  def meeting_part_when(meeting_on, today)
    [ meeting_on.strftime("%A, %B %-d"), "Midweek meeting", meeting_part_days_away((meeting_on - today).to_i) ].join(" · ")
  end

  private
    def meeting_part_days_away(days)
      case days
      when 0 then "today"
      when 1 then "tomorrow"
      when -1 then "yesterday"
      when 2.. then "in #{days} days"
      else "#{-days} days ago"
      end
    end
end
