# The submit button for "Cancel this session" (inside the confirmation dialog) and "Restore this session".
class FamilyStudies::Sessions::CancellationForm < ApplicationForm
  def initialize(label:, scheme: :default)
    @label = label
    @scheme = scheme
  end

  form do |f|
    f.submit(name: :submit, label: @label, scheme: @scheme)
  end
end
