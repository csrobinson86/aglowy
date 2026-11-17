# Everything on a household's calendar for a range of dates in its zone, as Items in order of start
# (docs/design/calendar.md, How a calendar is put together). Nothing is stored: each source is asked for the range.
# The sources are meetings, family studies and household events; hide leaves a group out without asking it.
class Household::Calendar
  GROUPS = { "meetings" => "Meetings", "family_studies" => "Family studies", "assemblies" => "Assemblies and special events",
             "field_service" => "Field service", "other_events" => "Other events" }.freeze
  # Which Show group each household event kind is in.
  EVENT_GROUPS = { "circuit_assembly" => "assemblies", "regional_convention" => "assemblies", "co_visit" => "assemblies",
                   "memorial" => "assemblies", "field_service" => "field_service", "other" => "other_events" }.freeze

  attr_reader :household, :viewer, :range

  def initialize(household, viewer:, range:, hide: [])
    @household = household
    @viewer = viewer
    @range = range
    @hide = hide
  end

  def items
    @items ||= [ *meetings, *studies, *events ].sort_by(&:starts_at)
  end

  def items_on(date)
    items.select { it.on?(date) }
  end

  # The week draws these as a band across the days they span, and the rest as cards under each day.
  def all_day_items
    items.select(&:all_day)
  end

  def timed_items_on(date)
    items_on(date).reject(&:all_day)
  end

  # No meeting times, no studies and no events: the page offers to set them up (docs/design/calendar.md, The page).
  def nothing_planned?
    !household.meeting_times_set? && household.family_studies.none? && household.events.none?
  end

  # The page is drawn in the household's zone, so a person whose profile is in another zone is told.
  def viewer_in_another_zone?
    viewer.time_zone.present? && viewer.time_zone != household.time_zone
  end

  # "Central Time (US & Canada)" reads as "Central Time".
  def zone_name
    household.time_zone.sub(/ \(.*\)\z/, "")
  end

  private
    def shown?(group)
      !group.in?(@hide)
    end

    def meetings
      return [] unless shown?("meetings")

      household.meetings_between(range).map { Item.from_meeting(it) }
    end

    def studies
      return [] unless shown?("family_studies")

      household.family_studies.flat_map { it.occurrences_between(range) }.map { Item.from_session(it) }
    end

    # One query for the kinds shown; each event's occurrences are expanded in Ruby (Trap 6).
    def events
      kinds = EVENT_GROUPS.select { |_, group| shown?(group) }.keys
      return [] if kinds.empty?

      household.events.preloaded.where(kind: kinds).flat_map do |event|
        event.occurrences_between(range).map { Item.from_event(event, it) }
      end
    end
end
