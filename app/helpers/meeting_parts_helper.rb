module MeetingPartsHelper
  # "Thursday, December 3 · Midweek meeting · in 16 days", under a part's heading (docs/design/meeting-parts.md, A part).
  def meeting_part_when(meeting_on, today)
    [ meeting_on.strftime("%A, %B %-d"), "Midweek meeting", meeting_part_days_away((meeting_on - today).to_i) ].join(" · ")
  end

  # "Private" or "Shared with <households>" beside the owner's own part.
  def meeting_part_sharing_label(part)
    part.shared_households.any? ? "Shared with #{part.shared_households.map(&:name).to_sentence}" : "Private"
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
