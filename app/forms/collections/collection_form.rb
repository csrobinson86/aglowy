# A collection's name and where it's used, from Personal study's side (frame docs/design/notes/notes-new-collection.png,
# drawn from the Notes side). New collections are used in both by default. A refused name or change comes back as error.
class Collections::CollectionForm < ApplicationForm
  def initialize(submit_label:, error: nil)
    @submit_label = submit_label
    @error = error
  end

  form do |f|
    f.text_field(name: :name, label: "Name", required: true, full_width: true, maxlength: 40, autofocus: @error.present?)
    f.radio_button_group(name: :used_in, label: "Use in", validation_message: @error) do |group|
      group.radio_button(value: "both", label: "Personal study and Notes")
      group.radio_button(value: "studies", label: "Personal study only")
    end
    f.submit(name: :submit, label: @submit_label, scheme: :primary)
  end
end
