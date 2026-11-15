require "application_system_test_case"

class DashboardTest < ApplicationSystemTestCase
  test "the household home passes assert_accessible as a head" do
    with_nothing_to_show
    sign_in identities(:head)

    visit household_root_url(household_id: households(:home))

    assert_selector "h1", text: "Home"
    assert_link "Add a member"
    assert_accessible
    capture_screens("home-head")
  end

  test "the household home passes assert_accessible as a child" do
    with_nothing_to_show
    sign_in child_identity

    visit household_root_url(household_id: households(:home))

    assert_selector "h2", text: "Welcome to The Head Family"
    assert_no_link "Add a member"
    assert_accessible
    capture_screens("home-child")
  end

  test "the household home with sessions passes assert_accessible" do
    family_study_sessions(:weekly_next).update!(scheduled_at: family_study_sessions(:weekly_next).scheduled_at + 4.days)
    sign_in identities(:head)

    visit household_root_url(household_id: households(:home))

    assert_selector "h2", text: "Next family study"
    assert_selector "h3", text: "Draw Close to Jehovah, chapter 1"
    assert_selector "h2", text: "Coming up"
    assert_link "All family studies"
    assert_accessible
    capture_screens("home-with-studies")
  end

  test "the household home with goals and notes passes assert_accessible as a head" do
    with_goals_and_notes
    sign_in identities(:head)

    visit household_root_url(household_id: households(:home))

    assert_link "Schedule a study"
    assert_selector "h2", text: "Next family study"
    assert_selector "h2", text: "Family goals"
    assert_selector "h2", text: "Mine · follows you to every household"
    assert_selector "h3", text: "My goals"
    assert_selector "h3", text: "Recent meeting notes"
    assert_accessible
    capture_screens("home-full")
    capture_screens("home-full-mine", scroll_to: ".household-home__aside h3")
  end

  # The app shell hides its own sidebar below md with a selector that also reaches Home's right column;
  # _household_home.scss shows it again.
  test "on a phone the right column stacks under the left" do
    with_goals_and_notes
    sign_in identities(:head)
    emulate_viewport(390, 844, phone: true)

    visit household_root_url(household_id: households(:home))

    assert_selector "h2", text: "Family goals", visible: true
    assert_selector "h3", text: "Recent meeting notes", visible: true
    assert_operator find("h2", text: "Family goals").rect.y, :>, find("h2", text: "Coming up").rect.y
  ensure
    cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "the household home with goals and notes passes assert_accessible as a child" do
    with_goals_and_notes(users(:child))
    sign_in child_identity

    visit household_root_url(household_id: households(:home))

    assert_selector "h2", text: "Family goals"
    assert_selector "h3", text: "My goals"
    assert_link "Read one Bible story each day"
    assert_no_link "Schedule a study"
    assert_accessible
    capture_screens("home-full-child")
  end

  private
    def with_nothing_to_show
      households(:home).family_studies.destroy_all
      Goal.destroy_all
      MeetingNote.destroy_all
    end

    def with_goals_and_notes(person = users(:head))
      family_study_sessions(:weekly_next).update!(scheduled_at: family_study_sessions(:weekly_next).scheduled_at + 4.days)
      households(:home).goals.create!(title: "Memorize Proverbs 3:5, 6", target_on: 2.months.from_now.to_date, set_by: users(:head))
      title = person == users(:head) ? "Read the Gospels by March" : "Read one Bible story each day"
      person.goals.create!(title:, target_on: 3.months.from_now.to_date, set_by: person)
      person.start_meeting_note(kind: "midweek", week_of: Date.current)
      person.start_meeting_note(kind: "weekend", week_of: Date.current - 1.week)
    end

    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
