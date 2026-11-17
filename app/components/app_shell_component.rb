# frozen_string_literal: true

# The household page frame: sidebar and main (docs/design/app-shell.md, Anatomy of the shell).
class AppShellComponent < ApplicationComponent
  # The phone menu dialog; the top bar's menu button opens it by this id.
  MENU_ID = "app-shell-menu"

  attr_reader :membership, :selected_item

  # The bell's accessible name comes from a hidden copy of the sidebar link's, so it updates live with it.
  BELL_NAME_ID = "app-shell-bell-name"

  def initialize(membership:, selected_item:)
    @membership = membership
    @selected_item = selected_item
  end

  # Counted once for the sidebar, the phone menu and the bell.
  def unread_notifications_count
    @unread_notifications_count ||= membership.user.unread_notifications_count
  end

  def notifications_path
    household_notifications_path(household_id: membership.household_id)
  end
end
