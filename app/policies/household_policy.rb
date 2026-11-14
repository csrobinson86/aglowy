class HouseholdPolicy < ApplicationPolicy
  def show?
    member? && membership.household_id == record.id
  end
end
