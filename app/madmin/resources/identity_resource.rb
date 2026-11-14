# No encrypted_password or tokens: Madmin shows every attribute listed here.
class IdentityResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :email
  attribute :staff, form: false
  attribute :confirmed_at, form: false
  attribute :confirmation_sent_at, form: false
  attribute :unconfirmed_email, form: false
  attribute :reset_password_sent_at, form: false
  attribute :remember_created_at, form: false
  attribute :failed_attempts, form: false
  attribute :locked_at, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # No association fields: Madmin 3.4.1 renders them via Madmin.resource_name_for,
  # which references ::ActiveStorage, and Active Storage isn't loaded yet.

  member_action do |record|
    button_to "Impersonate", main_app.admin_impersonation_path(identity_id: record.id), method: :post
  end

  def self.display_name(record) = record.email
end
