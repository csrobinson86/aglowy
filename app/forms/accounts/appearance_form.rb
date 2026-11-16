# Frames account-settings.png and account-settings-dark.png, Appearance (docs/design/app-shell.md, Theming and appearance).
class Accounts::AppearanceForm < ApplicationForm
  form do |f|
    f.radio_button_group(name: :appearance, label: "Theme") do |themes|
      themes.radio_button(value: "auto", label: "Match my device", caption: "Light or dark, following your phone or computer's setting.")
      themes.radio_button(value: "light", label: "Light", caption: "Always light, whatever your device is set to.")
      themes.radio_button(value: "dark", label: "Dark", caption: "Always dark. Easier on the eyes in the evening and at meetings.")
    end

    f.submit(name: :submit, label: "Save appearance")
  end
end
