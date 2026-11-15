# Someone already signed in answering an invitation: joining or declining (docs/design/invitations.md, "Accepting").
# Only the login the invitation was sent to can answer it, compared normalized (docs/design/users.md, gotcha 18).
class InvitationAcceptance
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :token, :string
  attribute :identity

  delegate :household, :invited_by, :role, to: :invitation

  # Nil when the token is expired, resent, used, cancelled or tampered with.
  def invitation
    return @invitation if defined?(@invitation)

    @invitation = Invitation.find_acceptable(token)
  end

  # A username-only login has no email, so it never matches.
  def for_identity?
    identity.email.present? && Invitation.normalize_value_for(:email, identity.email) == invitation.email
  end

  # Under the household's lock, like cancelling and resending, the token is resolved again: a resend or cancel that
  # committed since the page was shown leaves nothing to accept, and a double click can't join twice. Someone who
  # left is seated again with the invited role; their old shares stay ended. An active member keeps their seat.
  def join
    answer do
      membership = household.memberships.find_or_initialize_by(user: identity.user)
      membership.update!(role: invitation.role, active: true) unless membership.persisted? && membership.active?
    end
  end

  def decline
    answer
  end

  private
    def answer
      return false unless invitation && for_identity?

      ActiveRecord::Base.transaction do
        household.lock!
        @invitation = Invitation.find_acceptable(token)
        if invitation
          yield if block_given?
          invitation.destroy!
        end
      end

      invitation.present?
    end
end
