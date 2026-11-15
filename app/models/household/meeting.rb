# One occurrence of a household's midweek or weekend meeting, built by Household#current_or_next_meeting
# (docs/design/meeting-helper.md, Meeting times). starts_at is in the household's time zone.
Household::Meeting = Data.define(:kind, :starts_at) do
  self::LENGTH = 2.hours
  self::TITLES = { "midweek" => "Midweek meeting", "weekend" => "Weekend meeting" }.freeze

  # A Sunday weekend meeting belongs to the week that started the Monday before, like MeetingNote's week_of.
  def week_of
    starts_at.to_date.beginning_of_week(:monday)
  end

  def ends_at
    starts_at + self.class::LENGTH
  end

  # It stays today's meeting for the rest of its day, and until it ends if it runs past midnight.
  def current_until
    [ ends_at, starts_at.end_of_day ].max
  end

  def title
    self.class::TITLES.fetch(kind)
  end
end
