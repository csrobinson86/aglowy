# A device's "Remove" button in Phones and browsers. The aria-label names the device, so a screen reader can tell the
# rows apart.
class PushSubscriptions::RemovalForm < ApplicationForm
  def initialize(label:)
    @label = label
  end

  form do |f|
    f.submit(name: :submit, label: "Remove", scheme: :danger, size: :small, aria: { label: "Remove #{@label}" })
  end
end
