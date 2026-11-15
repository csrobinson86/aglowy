# Someone new to Aglowy accepting an invitation: a User, a confirmed Identity with the invitation's email and a
# Membership with the invited role, written together, then the invitation deleted. It never creates a household
# (docs/design/users.md, gotcha 13), so it isn't a Signup.
class InvitationSignup
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :token, :string
  attribute :name, :string
  attribute :password, :string

  attr_reader :identity

  validates :name, :password, presence: true

  delegate :email, :household, :invited_by, :role, :expires_on, to: :invitation

  # Nil when the token is expired, resent, used, cancelled or tampered with.
  def invitation
    return @invitation if defined?(@invitation)

    @invitation = Invitation.find_acceptable(token)
  end

  # The account's email is always the invitation's (docs/design/invitations.md, Traps), so one sent in is dropped.
  def email=(_ignored); end

  # Under the household's lock, like cancelling and resending, the token is resolved again: a resend or cancel that
  # committed since the page was shown leaves nothing to accept, and a double click can't join twice. The email
  # was sent to this address, so the identity is confirmed and Devise mails nothing.
  def save
    return false unless invitation && valid?

    ActiveRecord::Base.transaction do
      household.lock!
      @invitation = Invitation.find_acceptable(token)
      join if invitation
    end

    invitation.present?
  rescue ActiveRecord::RecordInvalid => invalid
    errors.merge!(invalid.record.errors)
    false
  rescue ActiveRecord::RecordNotUnique => conflict
    # Someone signed up with this email after the page was shown (gotcha 3).
    raise unless conflict.message.include?("index_identities_on_email")

    errors.add(:email, :taken)
    false
  end

  private
    def join
      user = User.create!(name: name)
      @identity = user.create_identity!(email: invitation.email, password: password, &:skip_confirmation!)
      household.memberships.create!(user: user, role: invitation.role)
      invitation.destroy!
    end
end
