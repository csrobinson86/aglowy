# frozen_string_literal: true

# The sidebar's household switcher (docs/design/app-shell.md, Anatomy of the shell). With two or more active
# households it's a menu of them; with one there's nothing to choose, so it's the same two lines as plain text.
# "New household" is in Settings → My households, not here. Previews pass unsaved memberships; pages use the
# person's active ones. A page can hold several switchers (sidebar, phone top bar, phone menu), each with its own menu_id.
class AppShell::HouseholdSwitcherComponent < ApplicationComponent
  attr_reader :membership, :memberships, :menu_id

  delegate :household, to: :membership

  def initialize(membership:, menu_id: "household-switcher", memberships: membership.user.memberships.active.by_household_name)
    @membership = membership
    @menu_id = menu_id
    @memberships = memberships.to_a
  end

  def menu? = memberships.many?

  def current?(other)
    other.household_id == membership.household_id
  end
end
