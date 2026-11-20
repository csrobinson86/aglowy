require "test_helper"

# What each scheduled kind says and opens, worked out when it's shown (docs/design/notifications.md, The kinds).
class Notification::KindTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @household = households(:home)
  end

  test "weekly_preview: your week in the household, the week's meetings, and that week on the calendar" do
    @household.family_studies.destroy_all
    @household.events.delete_all
    @household.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    notification = notify(:child, kind: "weekly_preview", subject: @household, data: { week_of: Date.new(2026, 11, 23) })

    @household.update!(name: "The Rivera Family")

    assert_equal "Your week in The Rivera Family", notification.title
    assert_equal "2 meetings", notification.body
    assert_equal household_calendar_path(household_id: @household, view: "week", date: "2026-11-23"), notification.target_path
    assert_equal [ :calendar, :purple, :right_away ], [ notification.icon, notification.color, notification.email ]
  end

  test "weekly_preview leaves out meeting parts, even one shared with the household" do
    @household.family_studies.destroy_all
    @household.events.delete_all
    @household.change_meeting_times(midweek_wday: 4, midweek_time: "19:00", weekend_wday: 0, weekend_time: "10:00")
    users(:head).meeting_parts.create!(kind: "talk", meeting_on: Date.new(2026, 11, 26), minutes: 5, topic: "Trust").share_with(@household)
    users(:head).meeting_parts.create!(kind: "following_up", meeting_on: Date.new(2026, 11, 27), minutes: 4, topic: "Hope")

    notification = notify(:child, kind: "weekly_preview", subject: @household, data: { week_of: Date.new(2026, 11, 23) })

    assert_equal "2 meetings", notification.body
  end

  test "weekly_preview names each day a study or event repeats, and one meeting in the singular" do
    @household.family_studies.destroy_all
    @household.events.delete_all
    travel_to(Time.utc(2026, 11, 17)) do
      @household.schedule_family_study(frequency: "weekly", starts_on: Date.new(2026, 11, 24), time_of_day: "19:00")
      @household.schedule_family_study(frequency: "once", starts_on: Date.new(2026, 11, 26), time_of_day: "19:00")
    end
    @household.events.create!(kind: "field_service", title: "Field service", starts_on: Date.new(2026, 11, 28), time_of_day: "09:30", duration_minutes: 90, created_by: users(:head))
    @household.events.create!(kind: "co_visit", title: "Circuit overseer's visit", starts_on: Date.new(2026, 11, 20), days: 6, created_by: users(:head))
    @household.change_meeting_times(midweek_wday: 1, midweek_time: "19:00", weekend_wday: 1, weekend_time: "10:00")

    notification = notify(:head, kind: "weekly_preview", subject: @household, data: { week_of: Date.new(2026, 11, 23) })

    assert_equal "2 meetings · family study Tuesday and Thursday · Circuit overseer's visit until Wednesday · Field service Saturday", notification.body
  end

  test "weekly_preview keeps two events over several days apart when they share a title" do
    @household.family_studies.destroy_all
    @household.events.delete_all
    @household.events.create!(kind: "circuit_assembly", title: "Trip", starts_on: Date.new(2026, 11, 24), days: 2, created_by: users(:head))
    @household.events.create!(kind: "circuit_assembly", title: "Trip", starts_on: Date.new(2026, 11, 27), days: 2, created_by: users(:head))
    @household.change_meeting_times(midweek_wday: 1, midweek_time: "19:00", weekend_wday: 1, weekend_time: "10:00")

    notification = notify(:head, kind: "weekly_preview", subject: @household, data: { week_of: Date.new(2026, 11, 23) })

    assert_equal "2 meetings · Trip from Tuesday · Trip from Friday", notification.body
  end

  test "study_topic_needed: the session's day, choose a topic before its date, and the session" do
    session = travel_to(Time.utc(2026, 11, 17)) do
      @household.schedule_family_study(frequency: "once", starts_on: Date.new(2026, 11, 24), time_of_day: "19:00").first_session
    end
    notification = notify(:head, kind: "study_topic_needed", subject: session)

    assert_equal "Tuesday's family study has no topic yet", notification.title
    assert_equal "Choose a topic, or draft one with AI, before Tuesday, November 24.", notification.body
    assert_equal household_family_study_session_path(household_id: @household, family_study_id: session.family_study, id: session), notification.target_path
    assert_equal [ :book, :blue, :right_away ], [ notification.icon, notification.color, notification.email ]
  end

  test "invitation_unaccepted: who was invited and how long ago, and Members" do
    invitation = travel_to(Time.utc(2026, 11, 12, 13)) { @household.invitations.create!(email: "grandpa@example.com", invited_by: users(:head)) }
    notification = travel_to(Time.utc(2026, 11, 17, 14)) { notify(:head, kind: "invitation_unaccepted", subject: invitation) }

    assert_equal "Your invitation hasn't been accepted", notification.title
    travel_to(Time.utc(2026, 11, 17, 14)) do
      assert_equal "grandpa@example.com was invited 5 days ago. Send it again?", notification.body
    end
    assert_equal household_members_path(household_id: @household), notification.target_path
    assert_equal [ :mail, :gray, :summary ], [ notification.icon, notification.color, notification.email ]
  end

  private
    def notify(person, kind:, subject:, data: {})
      users(person).notify(kind:, household: @household, subject:, data:, dedupe_key: "#{kind}:#{subject.id}")
    end
end
