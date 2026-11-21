# Settings → Children (docs/design/settings.md). The frames draw a switch; it's a check box and Save, because Primer's
# ToggleSwitch posts to one URL (docs/design/meeting-helper.md, Pages). Get ready's box shows only while the helper is
# on (docs/design/meeting-prep.md, The Settings check box); its caption template links to this week's cards while it's
# on. Each switch, while on, says who turned it on.
class Settings::MeetingHelperForm < ApplicationForm
  def initialize(meeting_helper:, meeting_prep:, cards_path:)
    @meeting_helper = meeting_helper
    @meeting_prep = meeting_prep
    @cards_path = cards_path
  end

  form do |f|
    f.check_box(name: :enabled, label: "Meeting helper for children", checked: @meeting_helper.present?,
                caption: "Children who sign in get \"Today's meeting\": one calm, picture-led prompt for each part of the " \
                         "midweek and weekend meetings. They mark what they heard and draw what they saw, and it's kept as " \
                         "their own meeting note.#{turned_on(@meeting_helper)}")
    if @meeting_helper
      f.check_box(name: :meeting_prep, label: "Get ready cards", checked: @meeting_prep.present?)
    end
    f.submit(name: :submit, label: "Save")
  end

  private
    def turned_on(switch)
      return unless switch

      " Turned on by #{switch.enabled_by.name} on #{switch.created_at.in_time_zone(switch.household.time_zone).strftime("%B %-d")}."
    end
end
