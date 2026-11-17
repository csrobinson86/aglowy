# A collection's name and where it's used, in its Edit Dialog on Settings → Tags and collections (frame
# settings-tags.png). All three choices, since it's neither section's page. A refused change comes back as error.
class Settings::CollectionForm < ApplicationForm
  def initialize(error: nil)
    @error = error
  end

  form do |f|
    f.text_field(name: :name, label: "Name", required: true, full_width: true, maxlength: 40, autofocus: @error.present?)
    f.radio_button_group(name: :used_in, label: "Use in", validation_message: @error) do |group|
      group.radio_button(value: "both", label: "Notes and Personal study")
      group.radio_button(value: "studies", label: "Personal study only")
      group.radio_button(value: "notes", label: "Notes only")
    end
    f.hidden(name: :section, value: "settings", scope_name_to_model: false)
    f.submit(name: :submit, label: "Save collection", scheme: :primary)
  end
end
