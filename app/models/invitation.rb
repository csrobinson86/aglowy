class Invitation < ApplicationRecord
  VALID_FOR = 7.days

  belongs_to :household
  belongs_to :invited_by, class_name: "User", inverse_of: :sent_invitations

  # Children get usernames, not invitations (docs/design/invitations.md).
  enum :role, %w[ adult head ].index_by(&:itself), default: :adult, validate: true

  scope :preloaded, -> { includes(:invited_by) }
  scope :newest_first, -> { order(created_at: :desc) }

  attribute :expires_at, default: -> { VALID_FOR.from_now }

  # Compared normalized at acceptance (gotcha 18).
  normalizes :email, with: -> { it.strip.downcase }

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "Enter an email address, like name@example.com." }
  validates :email, uniqueness: { scope: :household_id }
  validate :not_already_a_member

  # Moving expires_at (resending) invalidates the links in earlier emails. The token is never stored.
  generates_token_for :acceptance, expires_in: VALID_FOR do
    expires_at
  end

  # The token's own lifetime starts when the email job generates it, so it can outlive the deadline the
  # email shows by a little. The deadline is what counts: accept and decline look up through here only.
  def self.find_acceptable(token)
    find_by_token_for(:acceptance, token)&.then { it unless it.expired? }
  end

  def expired?
    expires_at.past?
  end

  # The deadline's date in the household's time zone, as the email and the Members page show it.
  def expires_on
    expires_at.in_time_zone(household.time_zone).to_date
  end

  # For someone signed in with another email: enough to recognise their own address, never the whole of it.
  def masked_email
    name, domain = email.split("@", 2)
    "#{name.first}•••••@#{domain}"
  end

  def deliver_later
    InvitationMailer.with(invitation: self).invite.deliver_later
  end

  # Under the household's lock, like accepting and cancelling, so a resend never lands mid-join. Reading the row
  # again under the lock raises RecordNotFound if a join or cancel deleted it first. False, and no email, if the
  # address has since become a member's.
  def resend
    resent = transaction do
      household.lock!
      lock!
      update(expires_at: VALID_FOR.from_now)
    end
    deliver_later if resent
    resent
  end

  # Under the same lock as joining, so a cancel and a join never both land (docs/design/invitations.md, "Accepting").
  def cancel
    transaction do
      household.lock!
      lock!
      destroy!
    end
  end

  private
    def not_already_a_member
      if household && household.memberships.active.joins(user: :identity).exists?(identities: { email: email })
        errors.add(:email, "Already a member of this household.")
      end
    end
end
