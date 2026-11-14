# frozen_string_literal: true

# The sidebar's household switcher (docs/design/app-shell.md, Anatomy of the shell).
# Previews pass unsaved memberships; pages use the person's active ones.
class AppShell::HouseholdSwitcherComponent < ApplicationComponent
  attr_reader :membership, :memberships

  delegate :household, to: :membership

  def initialize(membership:, memberships: membership.user.memberships.active.by_household_name)
    @membership = membership
    @memberships = memberships
  end

  def current?(other)
    other.household_id == membership.household_id
  end

  # Showing the item isn't authorization: HouseholdsController still authorizes.
  def show_new_household?
    Pundit.policy!(membership, Household).create?
  end
end
