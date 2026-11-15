# Field names are what Devise reads: identity[login], identity[password], identity[remember_me].
class Sessions::SignInForm < ApplicationForm
  form do |f|
    # One field for an email or a username (docs/design/invitations.md).
    f.text_field(name: :login, label: "Email or username", autocomplete: "username", autocapitalize: "none", spellcheck: false, autofocus: true)
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
