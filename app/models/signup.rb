# A new account is four rows: an Identity, its User, a Household and a head
# Membership, written together or not at all (docs/design/users.md, gotcha 1).
class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :email, :string
  attribute :password, :string
  attribute :household_name, :string
  attribute :time_zone, :string, default: "UTC"

  validates :name, :email, :password, :household_name, presence: true

  # Devise mails the confirmation in an after_commit, so it goes out only if all four commit.
  #
  # A taken email answers as a new one does, so sign-up doesn't tell anyone who has an account; the owner hears instead
  # (gotcha 25). The Identity is written last: what comes before it doesn't read the email, so it fails (a blank time
  # zone) the same either way, and nothing after it can fail. Its other errors (a short password) stay.
  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      user = User.create!(name: name, time_zone: time_zone)
      Household.create_with_head(household: { name: household_name, time_zone: time_zone }, head: user)
      user.create_identity!(email: email, password: password)
    end

    true
  rescue ActiveRecord::RecordInvalid => invalid
    invalid.record.errors.delete(:email, :taken)
    errors.merge!(invalid.record.errors)
    errors.none? && tell_existing_account
  rescue ActiveRecord::RecordNotUnique => conflict
    # Another sign-up took the email between Devise's check and our insert (gotcha 3).
    raise unless conflict.message.include?("index_identities_on_email")

    tell_existing_account
  end

  private
    # Someone who never confirmed needs the confirmation link to get in; anyone else is told they already have an account.
    def tell_existing_account
      identity = Identity.find_by!(email: email)

      if identity.confirmed?
        IdentityMailer.existing_account(identity).deliver_later
      else
        identity.resend_confirmation_instructions
      end

      true
    rescue SolidQueue::Job::EnqueueError => error
      # Active Job returns false for its own EnqueueError; Solid Queue raises its own. A new email's sign-up doesn't wait
      # on the queue, so a server error here would say the email has an account.
      Rails.error.report(error)
      true
    end
end
