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

  delegate :name, :first_name, to: :user

  # The link a head or adult makes for a child to choose a password (docs/design/invitations.md, Child logins).
  # Setting a password changes encrypted_password, so a link works once.
  generates_token_for :password_setup, expires_in: 12.hours do
    encrypted_password.last(10)
  end

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

  # Signs in with an email, as saved. A username-only login (a child's) has none, so it never sees an Email field.
  def email_login?
    email_in_database.present?
  end

  # A username-only login can't receive an unlock email, so it unlocks by time.
  def unlock_strategy_enabled?(strategy)
    super && (email.present? || strategy != :email)
  end

  protected
    # The confirmation link for a changed email is enqueued (story #111); Devise's other mail still goes now.
    # Devise sends it after commit, so the job finds the saved record.
    def send_devise_notification(notification, *args)
      if notification == :confirmation_instructions && pending_reconfirmation?
        devise_mailer.send(notification, self, *args).deliver_later
      else
        super
      end
    end

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
