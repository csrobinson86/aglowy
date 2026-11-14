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
  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      user = User.create!(name: name, time_zone: time_zone)
      user.create_identity!(email: email, password: password)
      Household.create_with_head(household: { name: household_name, time_zone: time_zone }, head: user)
    end

    true
  rescue ActiveRecord::RecordInvalid => invalid
    errors.merge!(invalid.record.errors)
    false
  end
end
