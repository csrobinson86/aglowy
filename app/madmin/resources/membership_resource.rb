# Read-only: changing a role or deactivating a seat here would skip the last-head guard (gotcha 5).
class MembershipResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :household_id, form: false
  attribute :user_id, form: false
  attribute :role, form: false
  attribute :active, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # No association fields: Madmin 3.4.1 renders them via Madmin.resource_name_for,
  # which references ::ActiveStorage, and Active Storage isn't loaded yet.

  def self.readonly? = true

  def self.display_name(record) = "#{record.user.name} in #{record.household.name}"
end
