# The submit button for Resend, Send again and Cancel on an invitation's row of the Members page. The aria-label
# names the address, so a screen reader can tell the rows' buttons apart.
class Invitations::ActionForm < ApplicationForm
  def initialize(label:, aria_label:, scheme: :default)
    @label = label
    @aria_label = aria_label
    @scheme = scheme
  end

  form do |f|
    f.submit(name: :submit, label: @label, scheme: @scheme, aria: { label: @aria_label })
  end
end
