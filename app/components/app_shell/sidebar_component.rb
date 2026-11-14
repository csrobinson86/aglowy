# frozen_string_literal: true

# The sidebar's contents, kept apart so the phone menu can render the same thing.
class AppShell::SidebarComponent < ApplicationComponent
  attr_reader :membership, :selected_item

  delegate :household, :user, to: :membership

  def initialize(membership:, selected_item:)
    @membership = membership
    @selected_item = selected_item
  end

  def home_path
    household_root_path(household_id: household.id)
  end

  def initial
    user.name.first
  end
end
