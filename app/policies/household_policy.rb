class HouseholdPolicy < ApplicationPolicy
  # No household in the URL here, so the membership is nil: any signed-in person may.
  def index?  = true
  def create? = true

  def show?
    member? && membership.household_id == record.id
  end
end
