# Shared, read-only, with households its owner (the record's user) belongs to, one sharing per household.
# Leaving a household ends the owner's shares there for good: Membership#deactivate deletes them, and
# shared_with joins the owner's active membership as a second guard, so rejoining never brings an old
# share back (docs/design/meeting-notes.md, "Leaving ends a share for good"; docs/design/goals.md, Goal::Sharing).
module Shareable
  extend ActiveSupport::Concern

  included do
    has_many :sharings, dependent: :delete_all
    has_many :shared_households, -> { order(:name) }, through: :sharings, source: :household

    # Shared there by an owner who is still an active member there.
    scope :shared_with, ->(household) do
      joins(:sharings).where(sharings: { household_id: household }).where(user_id: household.memberships.active.select(:user_id))
    end
  end

  # Takes the household lock Membership#deactivate takes and rechecks the owner's active membership behind it,
  # so a share can't slip in just after the owner leaves. Not a member (or no owner, as on a family goal):
  # RecordNotFound, a 404. The lock also serializes two shares at once, so sharing twice leaves one record.
  def share_with(household)
    transaction do
      household.lock!
      household.memberships.active.find_by!(user_id: user_id)
      sharings.find_or_create_by!(household: household)
    end
    shared_households.reset
  end

  # The filtered delete_all leaves loaded sharings alone, so they're reset for the page that answers from this record.
  def stop_sharing_with(household)
    sharings.where(household: household).delete_all
    sharings.reset
    shared_households.reset
  end

  # Reads the loaded sharings, so a list that includes them asks nothing more.
  def shared_with?(household)
    sharings.any? { it.household_id == household.id }
  end

  # The owner's other active households that won't see it once it's shared with this one, as the share
  # dialog names them. One it's already shared with is left out, so the dialog never says a household that
  # can read it won't.
  def households_not_shared_with_besides(household)
    user.active_households.where.not(id: household).where.not(id: sharings.select(:household_id)).order(:name)
  end
end
