# Preview at http://localhost:3000/rails/mailers/invitation_mailer. Built in memory, so it needs no data.
class InvitationMailerPreview < ActionMailer::Preview
  def invite
    invitation = Invitation.new(household: Household.new(name: "Rivera household"), invited_by: User.new(name: "Maria Rivera"), email: "daniel@example.com")

    InvitationMailer.with(invitation: invitation).invite
  end
end
