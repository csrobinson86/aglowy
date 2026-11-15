class InvitationMailer < ApplicationMailer
  # Accepted, declined or cancelled before the job ran: the invitation is gone, so there's nothing to send.
  rescue_from(ActiveJob::DeserializationError) { }

  # Takes the invitation, never a token: the token is made here, inside the job, and never stored or queued.
  def invite
    @invitation = params[:invitation]
    # A query parameter, never a path segment, so filter_parameters keeps it out of the logs (docs/design/invitations.md, Traps).
    @accept_url = invitation_acceptance_url(token: @invitation.generate_token_for(:acceptance))
    @deadline = @invitation.expires_on

    mail to: @invitation.email, subject: "#{@invitation.invited_by.name} invited you to the #{@invitation.household.name} on Aglowy"
  end
end
