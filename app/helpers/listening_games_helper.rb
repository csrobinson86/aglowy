module ListeningGamesHelper
  # "November 9–15, 2026", or "November 30 – December 6, 2026" across two months.
  def listening_game_week(week_of)
    sunday = week_of + 6.days
    week_of.month == sunday.month ? "#{week_of.strftime("%B %-d")}–#{sunday.day}, #{sunday.year}" : "#{week_of.strftime("%B %-d")} – #{sunday.strftime("%B %-d, %Y")}"
  end
end
