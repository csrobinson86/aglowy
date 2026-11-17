require "application_system_test_case"

# The three scheduled kinds in the inbox (docs/design/notifications.md, The kinds and Recurring jobs; frame
# notifications.png). Hannah is the home household's head, as Maria is the Riveras' in the frames.
class ScheduledNotificationsTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @household = households(:home)
    @household.family_studies.destroy_all
    @household.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    travel_to(Time.utc(2026, 11, 17, 13)) do
      @invitation = @household.invitations.create!(email: "grandpa@example.com", invited_by: users(:head))
      @session = @household.schedule_family_study(frequency: "once", starts_on: Date.new(2026, 11, 25), time_of_day: "19:00").first_session
    end
  end

  test "after the three jobs run, Hannah's inbox shows the three rows, and each opens its target" do
    travel_to(Time.utc(2026, 11, 22, 8, 10)) { Notification::StudyTopicJob.perform_now }
    travel_to(Time.utc(2026, 11, 22, 14)) { Notification::InvitationFollowUpJob.perform_now }
    travel_to(Time.utc(2026, 11, 22, 18, 5)) { Notification::WeeklyPreviewJob.perform_now }
    travel_to Time.utc(2026, 11, 22, 18, 30)

    sign_in identities(:head)
    visit household_notifications_url(household_id: @household)

    assert_selector "main .Box-row", count: 3
    assert_text "Your week in The Head Family"
    assert_text "2 meetings · family study Wednesday"
    assert_text "Wednesday's family study has no topic yet"
    assert_text "Choose a topic, or draft one with AI, before Wednesday, November 25."
    assert_text "Your invitation hasn't been accepted"
    assert_text "grandpa@example.com was invited 5 days ago. Send it again?"
    assert_accessible
    capture_screens("notifications-scheduled")

    click_on "Your week in The Head Family"
    assert_current_path household_calendar_path(household_id: @household, view: "week", date: "2026-11-23")

    visit household_notifications_url(household_id: @household)
    click_on "Wednesday's family study has no topic yet"
    assert_current_path household_family_study_session_path(household_id: @household, family_study_id: @session.family_study, id: @session)

    visit household_notifications_url(household_id: @household)
    click_on "Your invitation hasn't been accepted"
    assert_current_path household_members_path(household_id: @household)
    assert_text "grandpa@example.com"
  end
end
