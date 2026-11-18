# The submit button for "Share part" (inside the share dialog) and "Stop sharing".
class MeetingParts::SharingForm < ApplicationForm
  # dialog_id: the Primer Dialog the button closes as it submits.
  def initialize(label:, scheme: :default, dialog_id: nil)
    @label = label
    @scheme = scheme
    @dialog_id = dialog_id
  end

  form do |f|
    f.submit(name: :submit, label: @label, scheme: @scheme, data: { submit_dialog_id: @dialog_id })
  end
end
