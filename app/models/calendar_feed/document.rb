# A person's phone feed, written in RFC 5545 by hand (docs/design/calendar.md, The phone feed): for each of their
# active households its meetings, family studies and events, then their own times with a reminder as each starts.
# Never anyone else's times, and no notes or links, only titles, times and places: a feed link can leak (Trap 5).
class CalendarFeed::Document
  DAYS_BACK = 30
  DAYS_AHEAD = 180

  def initialize(user)
    @user = user
    @stamp = Time.current
  end

  def to_s
    [ "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Aglowy//Calendar//EN", "CALSCALE:GREGORIAN", "METHOD:PUBLISH", "X-WR-CALNAME:Aglowy",
      *household_items, *own_times, "END:VCALENDAR" ].map { "#{fold(it)}\r\n" }.join
  end

  private
    attr_reader :user

    # Each household's items over its own days, with its name in the summary. Its calendar leaves out every time.
    def household_items
      user.active_households.order(:name, :id).flat_map do |household|
        calendar = Household::Calendar.new(household, viewer: user, range: around(household.today), hide: %w[ my_times shared_times ])
        calendar.items.flat_map do |item|
          vevent(uid(item, household), item.starts_at, item.ends_at, all_day: item.all_day, summary: "#{item.title} · #{household.name}",
                 location: (item.source.location if item.event?))
        end
      end
    end

    # The person's own times over the instants of their own days, in their own zone, each with a display alarm whose
    # DESCRIPTION, which RFC 5545 requires, repeats the title.
    def own_times
      zone = ActiveSupport::TimeZone[user.calendar_time_zone]
      days = around(Time.current.in_time_zone(zone).to_date)
      instants = zone.local(days.first.year, days.first.month, days.first.day)...days.last.next_day.then { zone.local(it.year, it.month, it.day) }

      user.personal_times.occurring_between(instants).flat_map do |occurrence|
        vevent("time-#{occurrence.personal_time.id}-#{occurrence.on}", occurrence.starts_at, occurrence.ends_at, summary: occurrence.title,
               alarm: [ "BEGIN:VALARM", "ACTION:DISPLAY", "TRIGGER:PT0M", "DESCRIPTION:#{escape(occurrence.title)}", "END:VALARM" ])
      end
    end

    def around(today)
      (today - DAYS_BACK)..(today + DAYS_AHEAD)
    end

    # Stable across fetches, so the phone updates an occurrence rather than adding another: the kind, what it comes from,
    # and its slot date in the household's zone. A study's is its slot's, recurrence_at, so storing or moving a session
    # keeps it.
    def uid(item, household)
      case item.source
      when Household::Meeting then "meeting-#{household.id}-#{item.source.kind}-#{item.starts_at.to_date}"
      when FamilyStudy::Session then "study-#{item.source.family_study_id}-#{item.source.recurrence_at.in_time_zone(household.time_zone).to_date}"
      else "event-#{item.source.id}-#{item.starts_at.to_date}"
      end
    end

    # In UTC, or as dates for an all-day item, whose end is the day after its last.
    def vevent(uid, starts_at, ends_at, summary:, all_day: false, location: nil, alarm: [])
      dates = all_day ? [ "DTSTART;VALUE=DATE:#{starts_at.strftime("%Y%m%d")}", "DTEND;VALUE=DATE:#{ends_at.strftime("%Y%m%d")}" ] : [ "DTSTART:#{utc(starts_at)}", "DTEND:#{utc(ends_at)}" ]

      [ "BEGIN:VEVENT", "UID:#{uid}@aglowy", "DTSTAMP:#{utc(@stamp)}", *dates, "SUMMARY:#{escape(summary)}",
        *("LOCATION:#{escape(location)}" if location.present?), *alarm, "END:VEVENT" ]
    end

    def utc(time)
      time.utc.strftime("%Y%m%dT%H%M%SZ")
    end

    # RFC 5545 TEXT: a backslash, semicolon or comma is escaped, and a line break becomes \n.
    def escape(text)
      text.gsub(/[\\;,]/) { "\\#{it}" }.gsub(/\r\n|\r|\n/, "\\n")
    end

    # At most 75 octets a line, each continuation starting with a space, never splitting a character.
    def fold(line)
      line.each_char.each_with_object([ +"" ]) do |char, lines|
        lines << +" " if lines.last.bytesize + char.bytesize > 75
        lines.last << char
      end.join("\r\n")
    end
end
