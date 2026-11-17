# The "Delete collection" button in its delete Dialog. section: "settings" comes back to Settings.
class Collections::DeleteForm < ApplicationForm
  def initialize(section: nil)
    @section = section
  end

  form do |f|
    f.hidden(name: :section, value: @section, scope_name_to_model: false) if @section
    f.submit(name: :submit, label: "Delete collection", scheme: :danger)
  end
end
