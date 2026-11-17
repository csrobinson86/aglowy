# frozen_string_literal: true

# The sidebar's contents, kept apart so the phone menu can render the same thing.
# Both are in the page at once, so each gets its own label: "Main" or "Menu".
class AppShell::SidebarComponent < ApplicationComponent
  attr_reader :membership, :selected_item, :label

  delegate :household, :user, to: :membership

  def todays_meeting_path
    household_todays_meeting_path(household_id: household.id)
  end

  # The shell passes the unread count it already has, so the desktop sidebar and the phone menu don't each count again.
  def initialize(membership:, selected_item:, label:, unread_notifications_count: nil)
    @membership = membership
    @selected_item = selected_item
    @label = label
    @unread_notifications_count = unread_notifications_count
  end

  def unread_notifications_count
    @unread_notifications_count ||= user.unread_notifications_count
  end

  def switcher_menu_id
    "household-switcher-#{label.parameterize}"
  end

  def home_path
    household_root_path(household_id: household.id)
  end

  def calendar_path
    household_calendar_path(household_id: household.id)
  end

  def family_studies_path
    household_family_studies_path(household_id: household.id)
  end

  def members_path
    household_members_path(household_id: household.id)
  end

  def goals_path
    household_goals_path(household_id: household.id)
  end

  def personal_studies_path
    household_personal_studies_path(household_id: household.id)
  end

  def personal_notes_path
    household_personal_notes_path(household_id: household.id)
  end

  def my_goals_path
    household_my_goals_path(household_id: household.id)
  end

  # Notifications, for everyone, above Settings (docs/design/notifications.md, The sidebar).
  def notifications_path
    household_notifications_path(household_id: household.id)
  end

  # Settings, for everyone. The layout selects it on every settings page: its id is the first part of controller_path,
  # "settings" for every Settings:: controller (docs/design/settings.md, The sidebar).
  def settings_path
    household_settings_path(household_id: household.id)
  end
end
