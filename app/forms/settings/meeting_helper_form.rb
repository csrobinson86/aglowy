# Settings → Children (docs/design/settings.md). The frames draw a switch; it's a check box and Save, because Primer's
# ToggleSwitch posts to one URL (docs/design/meeting-helper.md, Pages).
class Settings::MeetingHelperForm < ApplicationForm
  def initialize(enabled:)
    @enabled = enabled
  end

  form do |f|
    f.check_box(name: :enabled, label: "Meeting helper for children", checked: @enabled,
                caption: "Children who sign in get \"Today's meeting\": one calm, picture-led prompt for each part of the " \
                         "midweek and weekend meetings. They mark what they heard and draw what they saw, and it's kept as " \
                         "their own meeting note.")
    f.submit(name: :submit, label: "Save")
  end
end
