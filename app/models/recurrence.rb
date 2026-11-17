# Which dates a schedule produces, for family studies (scheduling rule 3) and household events
# (docs/design/calendar.md, Household::Event). Monthly follows RFC 5545: the fifth Tuesday skips
# months without one, and -1 is the last Tuesday (gotcha 17).
class Recurrence
  def initialize(frequency:, interval:, starts_on:, ends_on:, week_of_month:)
    @frequency = frequency
    @interval = interval
    @starts_on = starts_on
    @ends_on = ends_on
    @week_of_month = week_of_month
  end

  def dates(from:, through:)
    first, last = [ from, starts_on ].max, [ through, ends_on ].compact.min
    candidates(first, last).select { it.between?(first, last) }
  end

  private
    attr_reader :frequency, :interval, :starts_on, :ends_on, :week_of_month

    def candidates(first, last)
      case frequency
      when "once"    then [ starts_on ]
      when "daily"   then every(interval, first, last)
      when "weekly"  then every(interval * 7, first, last)
      when "monthly" then months(first, last).filter_map { weekday_in(it) }
      end
    end

    # Counted from starts_on, not from the range, so "every 2 weeks" keeps its rhythm.
    def every(days, first, last)
      (starts_on + (first - starts_on).to_i.ceildiv(days) * days).step(last, days).to_a
    end

    def months(first, last)
      skipped = months_since_start(first).ceildiv(interval) * interval

      skipped.step(by: interval).lazy.map { starts_on.beginning_of_month.next_month(it) }.take_while { it <= last }.to_a
    end

    def months_since_start(date)
      (date.year - starts_on.year) * 12 + date.month - starts_on.month
    end

    def weekday_in(month)
      weekdays = (month..month.end_of_month).select { it.wday == starts_on.wday }
      week_of_month == -1 ? weekdays.last : weekdays[week_of_month - 1]
    end
end
