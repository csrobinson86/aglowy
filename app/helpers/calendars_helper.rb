module CalendarsHelper
  # The calendar for a view and date, keeping the groups the Show checkboxes hide (docs/design/calendar.md, The page).
  def calendar_page_path(view, date, hide:)
    household_calendar_path(view:, date: date.iso8601, hide: hide.presence)
  end

  # "Tue 17" for the eye, "Today · Tuesday, November 17" for a screen reader; on a phone, where the days are a list, the
  # whole date shows (docs/design/calendar.md, On a phone).
  def calendar_day_heading(day, today:)
    shown = safe_join([ day.strftime("%a "), tag.span(day.day, class: "calendar-day__number") ])
    whole = [ ("Today" if day == today), day.strftime("%A, %B %-d") ].compact.join(" · ")
    safe_join([ tag.span(shown, class: "d-none d-md-inline", aria: { hidden: true }), tag.span(whole, class: "calendar-day__whole") ])
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
