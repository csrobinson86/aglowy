# Frame account-settings.png, Signing in. A username-only login gets no Email field (email: false).
# value: nil so a re-rendered form never sends a password back.
class Settings::SignInForm < ApplicationForm
  def initialize(email:)
    @email = email
  end

  form do |f|
    f.text_field(name: :email, label: "Email", type: :email, required: true, autocomplete: "email", full_width: true) if @email

    f.group(layout: :horizontal) do |passwords|
      passwords.text_field(name: :password, label: "New password", type: :password, value: nil, autocomplete: "new-password", full_width: true)
      passwords.text_field(name: :current_password, label: "Current password", type: :password, value: nil, autocomplete: "current-password",
                           full_width: true, caption: @email ? "Needed to change your email or password." : "Needed to change your password.")
    end

    f.submit(name: :submit, label: "Save sign-in details")
  end
end
