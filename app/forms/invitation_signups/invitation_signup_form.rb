# The email is shown read-only: the account's email is the invitation's, never the form's (docs/design/invitations.md,
# Accepting; frame accept-new-account.png).
class InvitationSignups::InvitationSignupForm < ApplicationForm
  form do |f|
    f.text_field(name: :name, label: "Your name", required: true, autocomplete: "name")
    f.text_field(name: :email, label: "Email", type: :email, readonly: true, autocomplete: "email",
                 caption: "The invitation was sent to this address, so it's already confirmed.")
    # value: nil so a re-rendered form never sends the password back.
    f.text_field(name: :password, label: "Password", type: :password, value: nil, required: true, autocomplete: "new-password")

    f.submit(name: :submit, label: "Create account and join", scheme: :primary, block: true)
  end
end
