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

  def go_bags_path
    household_go_bags_path(household_id: household.id)
  end

  # Daily brief, first in Mine, for heads and adults: children have none (docs/design/daily-brief.md, The sidebar).
  def daily_brief?
    user.may_have_daily_brief?
  end

  def daily_brief_path
    household_daily_brief_path(household_id: household.id)
  end

  # Get ready, under Today's meeting, for a child with this week's cards ready (docs/design/meeting-prep.md, Where she
  # finds it).
  def get_ready?
    MeetingPrepPolicy.new(membership, household).show? && household.prep_cards_this_week?
  end

  # Study guide, after Today's meeting, for a head or adult here with theirs on (docs/design/study-guide.md, Where people
  # find it).
  def study_guide?
    StudyGuidePolicy.new(membership, :study_guide).index? && user.study_guide_on?
  end

  def study_guides_path
    household_study_guides_path(household_id: household.id)
  end

  def meeting_preps_path
    household_meeting_preps_path(household_id: household.id)
  end

  def personal_studies_path
    household_personal_studies_path(household_id: household.id)
  end

  def personal_notes_path
    household_personal_notes_path(household_id: household.id)
  end

  # Meeting parts, for everyone, children too (docs/design/meeting-parts.md, The sidebar).
  def meeting_parts_path
    household_meeting_parts_path(household_id: household.id)
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
