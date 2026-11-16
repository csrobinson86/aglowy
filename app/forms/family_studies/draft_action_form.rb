# The submit button for "Stop", "Change", "Discard" and "Describe a study" in the AI panel: each deletes the draft's
# request (stops or discards it) and shows Describe (docs/design/family-studies.md, Routes).
class FamilyStudies::DraftActionForm < ApplicationForm
  def initialize(label:, scheme: :default)
    @label = label
    @scheme = scheme
  end

  form do |f|
    f.submit(name: :submit, label: @label, scheme: @scheme)
  end
end
