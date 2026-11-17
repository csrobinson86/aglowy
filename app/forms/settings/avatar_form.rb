# Frame settings-avatar.png, "Save color" under the color picker (ColorPickerComponent, an approved hand-built input),
# which the Avatar box renders in the same form.
class Settings::AvatarForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Save color")
  end
end
