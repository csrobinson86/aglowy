# A login: an email, a username or both (docs/design/invitations.md). A username
# never contains "@", so the one sign-in field can tell the two apart.
class Identity < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable,
         :validatable, :confirmable, :lockable

  belongs_to :user

  # No email is NULL, never "": the email-or-username check counts "" as present.
  normalizes :email, with: -> { it.strip.downcase.presence }
  normalizes :username, with: -> { it.strip.downcase }

  validates :username, format: { with: /\A[a-z0-9][a-z0-9.-]{2,29}\z/ }, uniqueness: { case_sensitive: false }, allow_nil: true

  delegate :name, to: :user

  # The sign-in field (Devise's authentication key).
  attr_writer :login

  def self.find_for_database_authentication(conditions)
    login = devise_parameter_filter.filter(conditions)[:login].to_s
    # lower(username) matches the unique index, so the lookup uses it.
    login.include?("@") ? find_by(email: login) : find_by(arel_table[:username].lower.eq(login))
  end

  def login
    @login || email || username
  end

  # A username-only login can't receive an unlock email, so it unlocks by time.
  def unlock_strategy_enabled?(strategy)
    super && (email.present? || strategy != :email)
  end

  protected
    def email_required?
      username.blank?
    end

    def confirmation_required?
      email.present? && super
    end

    # Devise drops reset links when an authentication key changes, but our key is
    # the virtual login, so watch the columns it reads.
    def clear_reset_password_token?
      super || will_save_change_to_email? || will_save_change_to_username?
    end
end
