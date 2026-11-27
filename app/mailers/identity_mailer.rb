# Mail about a login itself, outside any household.
class IdentityMailer < ApplicationMailer
  # Sign-up with an email that already has an account saves as a success, so it tells the owner instead
  # (docs/design/users.md, gotcha 25). Whoever typed the address may not be its owner, so it says nothing else.
  def existing_account(identity)
    mail to: identity.email, subject: "You already have an Aglowy account"
  end
end
