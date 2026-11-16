# A collection's name and where it's used (frame docs/design/notes/notes-new-collection.png). New collections are used
# in both by default. section: "notes" offers Notes' choices, and comes back to Notes; otherwise Personal study's.
# A refused name or change comes back as error.
class Collections::CollectionForm < ApplicationForm
  def initialize(submit_label:, error: nil, section: "studies")
    @submit_label = submit_label
    @error = error
    @section = section
  end

  form do |f|
    f.text_field(name: :name, label: "Name", required: true, full_width: true, maxlength: 40, autofocus: @error.present?)
    f.radio_button_group(name: :used_in, label: "Use in", validation_message: @error) do |group|
      if @section == "notes"
        group.radio_button(value: "both", label: "Notes and Personal study")
        group.radio_button(value: "notes", label: "Notes only")
      else
        group.radio_button(value: "both", label: "Personal study and Notes")
        group.radio_button(value: "studies", label: "Personal study only")
      end
    end
    f.hidden(name: :section, value: @section, scope_name_to_model: false) if @section == "notes"
    f.submit(name: :submit, label: @submit_label, scheme: :primary)
  end
end
