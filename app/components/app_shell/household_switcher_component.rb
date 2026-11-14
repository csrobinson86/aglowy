# frozen_string_literal: true

# The sidebar's household switcher (docs/design/app-shell.md, Anatomy of the shell).
# Previews pass unsaved memberships; pages use the person's active ones. A page
# can hold several switchers (sidebar, phone top bar, phone menu), each with its own menu_id.
class AppShell::HouseholdSwitcherComponent < ApplicationComponent
  attr_reader :membership, :memberships, :menu_id

  delegate :household, to: :membership

  def initialize(membership:, menu_id: "household-switcher", memberships: membership.user.memberships.active.by_household_name)
    @membership = membership
    @menu_id = menu_id
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
