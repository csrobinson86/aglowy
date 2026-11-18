# frozen_string_literal: true

# Today at the top of Home's Mine column (docs/design/calendar.md, Today on Home; frame home-today.png): the viewer's own
# times with their done boxes, and the household's meetings, study sessions and events, drawn as on the calendar, with
# meeting parts, the viewer's own and those shared here. Never another member's shared time. Marking a time done replaces its card here as on the calendar, by the same id.
class TodayComponent < ApplicationComponent
  attr_reader :household, :today, :meeting_helper, :manage_events, :title, :heading_tag

  # meeting_helper: today's meeting opens Today's meeting (a child with the helper on). manage_events: a household
  # event opens its edit dialog (heads and adults). title and heading_tag: "Today in Aglowy", an h2 beside the daily
  # brief's sections.
  def initialize(household:, viewer:, meeting_helper:, manage_events:, title: "Today", heading_tag: :h3)
    @household = household
    @today = household.today
    @calendar = Household::Calendar.new(household, viewer:, range: today..today, hide: %w[ shared_times ])
    @meeting_helper = meeting_helper
    @manage_events = manage_events
    @title = title
    @heading_tag = heading_tag
  end

  def items
    @items ||= @calendar.items_on(today)
  end
end
