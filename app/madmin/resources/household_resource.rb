# Read-only: staff look at households here; heads change them in the app.
class HouseholdResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :name
  attribute :time_zone
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # No association fields: Madmin 3.4.1 renders them via Madmin.resource_name_for,
  # which references ::ActiveStorage, and Active Storage isn't loaded yet.

  def self.readonly? = true

  def self.display_name(record) = record.name
end
