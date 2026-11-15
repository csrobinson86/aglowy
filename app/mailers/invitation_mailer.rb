class InvitationMailer < ApplicationMailer
  # Accepted, declined or cancelled before the job ran: the invitation is gone, so there's nothing to send.
  rescue_from(ActiveJob::DeserializationError) { }

  # Takes the invitation, never a token: the token is made here, inside the job, and never stored or queued.
  def invite
    @invitation = params[:invitation]
    @accept_url = accept_url_for(@invitation)
    @deadline = @invitation.expires_on

    mail to: @invitation.email, subject: "#{@invitation.invited_by.name} invited you to the #{@invitation.household.name} on Aglowy"
  end

  private
    # /invitation?token=…: a query parameter, never a path segment, so filter_parameters keeps it out of the
    # logs (docs/design/invitations.md, Traps). The accepting story draws the route; then this is
    # invitation_url(token: …). Drawn now, it would advertise a page that doesn't exist yet.
    def accept_url_for(invitation)
      "#{root_url}invitation?#{{ token: invitation.generate_token_for(:acceptance) }.to_query}"
    end
end
