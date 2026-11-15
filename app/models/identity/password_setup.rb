# A child choosing a password from the link a head or adult made (docs/design/invitations.md, Child logins).
# The token is the permission, so whoever opens the link needn't be signed in.
class Identity::PasswordSetup
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :token, :string
  attribute :password, :string
  attribute :password_confirmation, :string

  delegate :username, :first_name, to: :identity

  # Nil when the token is used, expired, missing or tampered with.
  def identity
    return @identity if defined?(@identity)

    @identity = Identity.find_by_token_for(:password_setup, token)
  end

  # Under the login's row lock the token is resolved again, so of two submissions with one link only the first
  # sets a password: the second finds encrypted_password changed and nothing to set. The new password also lifts
  # a lock left by the attempts that led to the forgotten password.
  def save
    return false unless identity

    saved = Identity.transaction do
      identity.lock!
      if Identity.find_by_token_for(:password_setup, token) == identity
        identity.update(password: password, password_confirmation: password_confirmation, failed_attempts: 0, locked_at: nil, unlock_token: nil)
      else
        @identity = nil
        false
      end
    end

    errors.merge!(identity.errors) if identity
    saved
  end
end
