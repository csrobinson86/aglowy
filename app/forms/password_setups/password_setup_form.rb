# Frame child-password.png. value: nil so a re-rendered form never sends a password back.
class PasswordSetups::PasswordSetupForm < ApplicationForm
  form do |f|
    f.text_field(name: :password, label: "Password", type: :password, value: nil, required: true, autocomplete: "new-password", full_width: true)
    f.text_field(name: :password_confirmation, label: "Type it again", type: :password, value: nil, required: true, autocomplete: "new-password", full_width: true)

    f.submit(name: :submit, label: "Save password and sign in", scheme: :primary, block: true)
  end
end
