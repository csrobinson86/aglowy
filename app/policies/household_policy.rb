class HouseholdPolicy < ApplicationPolicy
  # No household in the URL here, so the membership is nil: any signed-in person may.
  def index? = true

  # The membership is nil outside a household, so the record is the person who'd be the new household's head:
  # authorize Current.user, policy_class: HouseholdPolicy. Children can't (docs/design/invitations.md, Traps).
  def create? = record.can_start_household?

  def show?
    member? && membership.household_id == record.id
  end

  # Settings → Household (the name and time zone) and Members and roles: heads of this household only
  # (docs/design/settings.md, Sections and who sees them).
  def update?
    head? && membership.household_id == record.id
  end

  # Settings → Meetings and Children (the meeting times and the meeting helper): heads and adults of this household.
  def manage_meetings?
    head_or_adult? && membership.household_id == record.id
  end
end
