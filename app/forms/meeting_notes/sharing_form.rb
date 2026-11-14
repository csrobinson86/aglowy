# The submit button for "Share note" (inside the share dialog) and "Stop sharing".
class MeetingNotes::SharingForm < ApplicationForm
  def initialize(label:, scheme: :default)
    @label = label
    @scheme = scheme
  end

  form do |f|
    f.submit(name: :submit, label: @label, scheme: @scheme)
  end
end
