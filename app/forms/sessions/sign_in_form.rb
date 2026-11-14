# Field names are what Devise reads: identity[email], identity[password], identity[remember_me].
class Sessions::SignInForm < ApplicationForm
  form do |f|
    f.text_field(name: :email, label: "Email", type: :email, autocomplete: "email", autofocus: true)
    # value: nil so a failed sign-in never sends the password back. The
    # caption template puts "Forgot password?" under the field.
    f.text_field(name: :password, label: "Password", type: :password, value: nil, autocomplete: "current-password")
    f.check_box(name: :remember_me, label: "Remember me")
    f.submit(name: :submit, label: "Sign in", scheme: :primary, block: true)
  end

  # Form templates don't get route helpers, so the view passes the link in.
  def initialize(forgot_password_path:)
    @forgot_password_path = forgot_password_path
  end

  private
    attr_reader :forgot_password_path
end
