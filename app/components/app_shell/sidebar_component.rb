# frozen_string_literal: true

# The sidebar's contents, kept apart so the phone menu can render the same thing.
# Both are in the page at once, so each gets its own label: "Main" or "Menu".
class AppShell::SidebarComponent < ApplicationComponent
  attr_reader :membership, :selected_item, :label

  delegate :household, :user, to: :membership

  def initialize(membership:, selected_item:, label:)
    @membership = membership
    @selected_item = selected_item
    @label = label
  end

  def switcher_menu_id
    "household-switcher-#{label.parameterize}"
  end

  def home_path
    household_root_path(household_id: household.id)
  end

  def members_path
    household_members_path(household_id: household.id)
  end

  def initial
    user.name.first
  end
end
