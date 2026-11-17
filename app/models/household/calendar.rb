# Everything on a household's calendar for a range of dates in its zone, as Items in order of start
# (docs/design/calendar.md, How a calendar is put together). Nothing is stored: each source is asked for the range.
# CAL-01's first story has two sources, meetings and family studies; hide leaves a group out without asking it.
class Household::Calendar
  GROUPS = { "meetings" => "Meetings", "family_studies" => "Family studies" }.freeze

  attr_reader :household, :viewer, :range

  def initialize(household, viewer:, range:, hide: [])
    @household = household
    @viewer = viewer
    @range = range
    @hide = hide
  end

  def items
    @items ||= [ *meetings, *studies ].sort_by(&:starts_at)
  end

  def items_on(date)
    items.select { it.on?(date) }
  end

  # No meeting times and no studies: the page offers to set them up (docs/design/calendar.md, The page).
  def nothing_planned?
    !household.meeting_times_set? && household.family_studies.none?
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
end
