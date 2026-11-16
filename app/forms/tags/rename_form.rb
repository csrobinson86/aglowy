# The tag's new name in My tags' rename Dialog. A taken name, or one that normalizes to nothing, comes back as error,
# and autofocus puts the keyboard back on the field.
class Tags::RenameForm < ApplicationForm
  def initialize(error: nil)
    @error = error
  end

  form do |f|
    f.text_field(name: :name, label: "Name", required: true, full_width: true, autofocus: @error.present?, validation_message: @error)
    f.submit(name: :submit, label: "Rename", scheme: :primary)
  end
end
