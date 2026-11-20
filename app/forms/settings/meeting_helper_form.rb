# Settings → Children (docs/design/settings.md). The frames draw a switch; it's a check box and Save, because Primer's
# ToggleSwitch posts to one URL (docs/design/meeting-helper.md, Pages). Get ready's box shows only while the helper is
# on (docs/design/meeting-prep.md, The Settings check box). Each switch, while on, says who turned it on.
class Settings::MeetingHelperForm < ApplicationForm
  def initialize(meeting_helper:, meeting_prep:)
    @meeting_helper = meeting_helper
    @meeting_prep = meeting_prep
  end

  form do |f|
    f.check_box(name: :enabled, label: "Meeting helper for children", checked: @meeting_helper.present?,
                caption: "Children who sign in get \"Today's meeting\": one calm, picture-led prompt for each part of the " \
                         "midweek and weekend meetings. They mark what they heard and draw what they saw, and it's kept as " \
                         "their own meeting note.#{turned_on(@meeting_helper)}")
    if @meeting_helper
      f.check_box(name: :meeting_prep, label: "Get ready cards", checked: @meeting_prep.present?,
                  caption: "Each week, AI writes a few simple cards about both meetings, from this week's program on " \
                           "jw.org: what each part is about, something about Jehovah, and one thing to do. Children see " \
                           "them as soon as they're ready. You can read and change them.#{turned_on(@meeting_prep)}")
    end
    f.submit(name: :submit, label: "Save")
  end

  private
    def turned_on(switch)
      return unless switch

      " Turned on by #{switch.enabled_by.name} on #{switch.created_at.in_time_zone(switch.household.time_zone).strftime("%B %-d")}."
    end
end
