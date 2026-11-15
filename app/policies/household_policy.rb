class HouseholdPolicy < ApplicationPolicy
  # No household in the URL here, so the membership is nil: any signed-in person may.
  def index? = true

  # The membership is nil outside a household, so the record is the person who'd be the new household's head:
  # authorize Current.user, policy_class: HouseholdPolicy. Children can't (docs/design/invitations.md, Traps).
  def create? = record.can_start_household?

  def show?
    member? && membership.household_id == record.id
  end

  # Household settings' name and time zone: heads of this household only (docs/design/invitations.md, Who can do what).
  def update?
    head? && membership.household_id == record.id
  end

  # Heads and adults open Household settings; adults see only its Meetings section (docs/design/meeting-helper.md, Trap 10).
  def edit?
    head_or_adult? && membership.household_id == record.id
  end

  # Setting the meeting times: heads and adults of this household.
  def manage_meetings?
    head_or_adult? && membership.household_id == record.id
  end
end
