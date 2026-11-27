# Preview at http://localhost:3000/rails/mailers/identity_mailer. Built in memory, so it needs no data.
class IdentityMailerPreview < ActionMailer::Preview
  def existing_account
    IdentityMailer.existing_account(Identity.new(email: "maria@example.com"))
  end
end
