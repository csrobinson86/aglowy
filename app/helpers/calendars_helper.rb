module CalendarsHelper
  # The calendar for a view and date, keeping the groups the Show checkboxes hide (docs/design/calendar.md, The page).
  def calendar_page_path(view, date, hide:)
    household_calendar_path(view:, date: date.iso8601, hide: hide.presence)
  end

  # "Tue 17" for the eye, "Tuesday, November 17" for a screen reader.
  def calendar_day_heading(day)
    shown = safe_join([ day.strftime("%a "), tag.span(day.day, class: "calendar-day__number") ])
    safe_join([ tag.span(shown, aria: { hidden: true }), tag.span(day.strftime("%A, %B %-d"), class: "sr-only") ])
  end

  # The id of a personal time's card on one day, which marking it done replaces.
  def personal_time_card_id(occurrence)
    "personal_time_#{occurrence.personal_time.id}_#{occurrence.on.iso8601}"
  end

  def calendar_time(time)
    time.strftime("%-l:%M %p")
  end

  # An all-day event's days: "Sat 28", or "Tue 17 – Sun 22".
  def calendar_days(dates)
    [ dates.first, dates.last ].uniq.map { it.strftime("%a %-d") }.join(" – ")
  end
end
