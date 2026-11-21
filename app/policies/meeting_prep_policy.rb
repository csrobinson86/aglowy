# Get ready's pages while this household has both the meeting helper and Get ready on (docs/design/meeting-prep.md,
# Who can do what): her pages for a child of the household, and the parent's page and Change a card for its heads and
# adults. The record is the household. Its controllers answer 404, not the usual redirect, when it fails.
class MeetingPrepPolicy < ApplicationPolicy
  # Her Get ready page for a child, the parent's page for a head or adult.
  def index? = her_pages? || parents_page?

  def show? = her_pages?

  # Starting her note from a card, for her comment or Draw it!.
  def create? = her_pages?

  # Change a card, on the parent's page.
  def edit? = parents_page?

  def update? = parents_page?

  private
    def her_pages?
      member? && membership.child? && membership.household_id == record.id && record.meeting_prep?
    end

    def parents_page?
      HouseholdPolicy.new(membership, record).manage_meetings? && record.meeting_prep?
    end
end
