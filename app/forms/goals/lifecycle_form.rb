# The submit button for "Mark goal complete", "Reopen goal" and "Restore" in a goal's Banners, "Delete goal"
# in the delete Dialog, and "Share goal" and "Stop sharing" in its header.
class Goals::LifecycleForm < ApplicationForm
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
