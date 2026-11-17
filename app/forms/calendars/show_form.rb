# "Show" beside the calendar (docs/design/calendar.md, The page): a check box per group, sent as show[] whenever one
# changes, the household's groups and then "Times". The empty show[] says the form was sent even with nothing ticked.
# Each check box is drawn in its group's color; "<Name>'s times" in the shared times' pink. A phone's copy, in a
# dialog, is built with a namespace, which keeps its ids apart from the column's.
class Calendars::ShowForm < ApplicationForm
  KINDS = { "meetings" => "meeting", "family_studies" => "study", "assemblies" => "assembly", "field_service" => "field-service",
            "other_events" => "other", "my_times" => "my-time" }.freeze

  def initialize(calendar:, period:, hide:)
    @calendar = calendar
    @period = period
    @hide = hide
  end

  form do |f|
    f.hidden(name: :view, value: @period.view)
    f.hidden(name: :date, value: @period.date.iso8601)
    f.hidden(name: "show[]", value: "", id: @builder.field_id(:show, :sent))
    # Pairs, not a hash, so a household named "Times" keeps both groups.
    [ [ @calendar.household.name, Household::Calendar::GROUPS ], [ "Times", @calendar.time_groups ] ].each do |legend, groups|
      f.check_box_group(name: :show, label: legend) do |group|
        groups.each do |key, label|
          group.check_box(value: key, label:, checked: !key.in?(@hide), classes: "calendar-show__check calendar-show__check--#{KINDS.fetch(key, "shared")}")
        end
      end
    end
  end
end
