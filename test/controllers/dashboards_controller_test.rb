require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "a visitor is redirected to sign in" do
    get household_root_path(household_id: households(:home))

    assert_redirected_to new_identity_session_path
  end

  test "a member sees the Home header with the household name, and the member list has moved to Members" do
    with_nothing_to_show
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_response :success
    assert_select "h1", "Home"
    assert_select ".Subhead-description", /\AThe Head Family · /
    assert_select ".blankslate h2", "Welcome to The Head Family"
    assert_select "main", text: /Sam Spouse/, count: 0
    assert_select "header a[href='#{new_household_path}']"
  end

  test "the page title is Home · <household> · Aglowy" do
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select "title", "Home · The Head Family · Aglowy"
  end

  test "the household name in the page title is escaped" do
    households(:home).update!(name: "Tom & Jerry <b>")
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_includes response.body, "<title>Home · Tom &amp; Jerry &lt;b&gt; · Aglowy</title>"
  end

  test "a head and an adult see Add a member" do
    with_nothing_to_show
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity

      get household_root_path(household_id: households(:home))

      assert_select ".blankslate p", "Add the people in your household. Family studies, goals and notes will show up here as you add them."
      assert_select ".blankslate a[href='#{new_household_member_path(household_id: households(:home))}']", "Add a member"
    end
  end

  test "a child doesn't see Add a member" do
    with_nothing_to_show
    sign_in child_identity

    get household_root_path(household_id: households(:home))

    assert_response :success
    assert_select ".blankslate p", "Family studies, goals and notes will show up here."
    assert_select "a", { text: "Add a member", count: 0 }
  end

  test "a head's empty state offers Schedule a study first, then Add a member" do
    with_nothing_to_show
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".blankslate a.Button--primary[href='#{new_household_family_study_path(household_id: households(:home))}']", "Schedule a study"
    assert_select ".blankslate a:not(.Button--primary)[href='#{new_household_member_path(household_id: households(:home))}']", "Add a member"
  end

  test "an adult's empty state offers Schedule a study and Add a member; a child's offers nothing" do
    with_nothing_to_show
    sign_in identities(:spouse)
    get household_root_path(household_id: households(:home))
    assert_select ".blankslate a[href='#{new_household_family_study_path(household_id: households(:home))}']", "Schedule a study"
    assert_select ".blankslate a[href='#{new_household_member_path(household_id: households(:home))}']", "Add a member"

    sign_in child_identity
    get household_root_path(household_id: households(:home))
    assert_select ".blankslate a", count: 0
  end

  test "shows the next session and the next three after it" do
    weekly = family_studies(:weekly)
    later = [ 4, 5 ].map { |weeks| weekly.sessions.create!(recurrence_at: weekly.first_session_at + weeks.weeks, scheduled_at: weekly.first_session_at + weeks.weeks) }
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select ".blankslate", count: 0
    assert_select ".Box", text: /Next family study/ do
      assert_select ".Box-header .Label", "Weekly on #{weekly.starts_on.strftime("%A")}s"
      assert_select "h3", "Topic not chosen yet"
      assert_select "a[href='#{session_path(family_study_sessions(:weekly_next))}']", "Open study"
    end
    assert_select ".Box", text: /Coming up/ do
      assert_select ".Box-row a", count: 3
      assert_select ".Box-row:nth-of-type(1) a[href='#{session_path(family_study_sessions(:one_off_first))}']", text: /Draw Close to Jehovah, chapter 1/
      assert_select ".Box-row:nth-of-type(2) a[href='#{session_path(family_study_sessions(:weekly_later))}']"
      assert_select ".Box-row:nth-of-type(3) a[href='#{session_path(later.first)}']"
      assert_select "a[href='#{household_family_studies_path(household_id: households(:home))}']", "All family studies"
    end
    assert_select "a[href='#{session_path(later.last)}']", count: 0
  end

  test "the next session shows its topic and resources" do
    family_study_sessions(:weekly_next).update!(scheduled_at: family_study_sessions(:weekly_next).scheduled_at + 4.days)
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select ".Box", text: /Next family study/ do
      assert_select "h3", "Draw Close to Jehovah, chapter 1"
      assert_select "a[href='#{family_study_resources(:proverbs).url}'][target='_blank'][rel='noopener noreferrer']", family_study_resources(:proverbs).title
      assert_select "a[href='#{family_study_resources(:draw_close).url}']", family_study_resources(:draw_close).title
    end
  end

  test "skips cancelled sessions" do
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select "a[href='#{session_path(family_study_sessions(:weekly_next))}']", "Open study"
    assert_select "a[href='#{session_path(family_study_sessions(:weekly_cancelled))}']", count: 0
    assert_select "main", text: /Cancelled/, count: 0
  end

  test "the empty state when none" do
    households(:home).family_study_sessions.update_all(canceled_at: Time.current)
    with_no_goals_or_notes
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select ".blankslate h2", "Welcome to The Head Family"
    assert_select ".blankslate a[href='#{new_household_family_study_path(household_id: households(:home))}']", "Schedule a study"
    assert_select "main", text: /Next family study/, count: 0
  end

  test "with one upcoming session there is no Coming up box" do
    households(:home).family_study_sessions.where.not(id: family_study_sessions(:weekly_next)).update_all(canceled_at: Time.current)
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select "a", "Open study"
    assert_select "main", text: /Coming up/, count: 0
  end

  test "a head and an adult can schedule a study from the header once sessions exist; a child can't" do
    [ identities(:head), identities(:spouse) ].each do |identity|
      sign_in identity
      get household_root_path(household_id: households(:home))
      assert_select ".Subhead a[href='#{new_household_family_study_path(household_id: households(:home))}']", "Schedule a study"
    end

    sign_in child_identity
    get household_root_path(household_id: households(:home))
    assert_select "a", { text: "Schedule a study", count: 0 }
    assert_select "a", "Open study"
  end

  test "the description shows the household's name and today's date in its time zone" do
    households(:home).update_column(:time_zone, "Auckland")
    sign_in identities(:spouse)

    travel_to Time.utc(2026, 11, 13, 12) do
      assert_equal Date.new(2026, 11, 13), Date.current

      get household_root_path(household_id: households(:home))
    end

    assert_select ".Subhead-description", "The Head Family · Saturday, November 14"
  end

  test "with only an active family goal, Home shows the two columns and no Welcome" do
    with_nothing_to_show
    add_goals(households(:home), 1)
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_two_columns
  end

  test "with only a personal goal, Home shows the two columns and no Welcome" do
    with_nothing_to_show
    add_goals(users(:head), 1, set_by: users(:head))
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_two_columns
  end

  test "with only a meeting note, Home shows the two columns and no Welcome" do
    with_nothing_to_show
    users(:head).start_meeting_note(kind: "midweek", week_of: Date.current)
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_two_columns
  end

  test "with nothing at all, the Welcome Blankslate shows" do
    with_nothing_to_show
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".blankslate h2", "Welcome to The Head Family"
    assert_select "main .Layout", count: 0
    assert_select ".Subhead a", count: 0
  end

  test "with no session but other content, Next family study says none is scheduled" do
    households(:home).family_studies.destroy_all
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".Box", text: /Next family study/ do
      assert_select ".color-fg-muted", "No family study scheduled."
    end
    assert_select ".Subhead a[href='#{new_household_family_study_path(household_id: households(:home))}']", "Schedule a study"
  end

  test "family goals: at most 3 active ones are listed, set by whom and since when; completed or archived ones are not" do
    households(:home).update_column(:time_zone, "Auckland")
    goals(:gospels).update_column(:created_at, Time.utc(2026, 8, 31, 20))
    later = add_goals(households(:home), 3)
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select ".Box", text: /Family goals/ do
      assert_select ".Box-row", count: 3
      assert_select ".Box-row a[href='#{goal_path(goals(:gospels))}']", "Read the four Gospels together"
      assert_select ".Box-row .f6.color-fg-muted", "Set by Sam · since September 1"
      assert_select ".Box-row a[href='#{goal_path(later.first)}']"
      assert_select ".Box-row a[href='#{goal_path(later.second)}']"
      assert_select "a[href='#{goal_path(later.third)}']", count: 0
      assert_select "a[href='#{goal_path(goals(:proverbs))}']", count: 0
      assert_select "a[href='#{goal_path(goals(:songs))}']", count: 0
      assert_select ".Box-footer a[href='#{household_goals_path(household_id: households(:home))}']", "All family goals"
    end
  end

  test "with no active family goals, the Family goals box says so" do
    goals(:gospels).destroy
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select ".Box", text: /Family goals/ do
      assert_select ".Box-row.color-fg-muted", "No family goals yet."
      assert_select ".Box-footer a", "All family goals"
    end
  end

  test "another household's family goal is never listed" do
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select "main", text: /Read Acts together/, count: 0
  end

  test "My goals lists only the signed-in person's goals; another member's personal goal is not listed, even if shared" do
    goals(:spouse_bible_reading).share_with(households(:home))
    mine = add_goals(users(:head), 4, set_by: users(:head))
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select "h2", "Mine · follows you to every household"
    assert_select ".Box", text: /My goals/ do
      assert_select ".Box-row a", count: 3
      mine.first(3).each { assert_select ".Box-row a[href='#{goal_path(it)}']", it.title }
      assert_select ".Box-footer a[href='#{household_my_goals_path(household_id: households(:home))}']", "All my goals"
    end
    assert_select "a[href='#{goal_path(mine.last)}']", count: 0
    assert_select "main", text: /Read the whole Bible in a year/, count: 0
  end

  test "with no goals of their own, My goals says so" do
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".Box", text: /My goals/ do
      assert_select ".Box-row.color-fg-muted", "No goals yet."
    end
  end

  test "Recent meeting notes lists only the signed-in person's 2 newest notes" do
    older = users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))
    theirs = users(:spouse).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 23))
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".Box", text: /Recent meeting notes/ do
      assert_select ".Box-row", count: 2
      assert_select ".Box-row:nth-of-type(1) a[href='#{household_meeting_note_path(household_id: households(:home), id: meeting_notes(:head_weekend))}']", "Weekend meeting"
      assert_select ".Box-row:nth-of-type(1) .color-fg-muted", "Weekend of November 21–22, 2026"
      assert_select ".Box-row:nth-of-type(2) a[href='#{household_meeting_note_path(household_id: households(:home), id: meeting_notes(:head_midweek))}']", "Life and Ministry"
      assert_select "a[href*='#{older.id}']", count: 0
      assert_select ".Box-footer a[href='#{household_meeting_notes_path(household_id: households(:home))}']", "All meeting notes"
    end
    assert_select "a[href*='#{theirs.id}']", count: 0
  end

  test "with no meeting notes, Recent meeting notes says so" do
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_select ".Box", text: /Recent meeting notes/ do
      assert_select ".Box-row.color-fg-muted", "No meeting notes yet."
    end
  end

  test "Home asks no query per goal, note or session" do
    sign_in identities(:head)
    get household_root_path(household_id: households(:home))
    few = queries_during_get

    add_goals(households(:home), 3, set_by: users(:head))
    add_goals(households(:home), 2, set_by: users(:child))
    add_goals(users(:head), 3, set_by: users(:head))
    weekly = family_studies(:weekly)
    [ 4, 5 ].each { |weeks| weekly.sessions.create!(recurrence_at: weekly.first_session_at + weeks.weeks, scheduled_at: weekly.first_session_at + weeks.weeks) }
    users(:head).start_meeting_note(kind: "midweek", week_of: Date.new(2026, 11, 9))

    assert_equal few, queries_during_get
  end

  test "a non-member gets 404" do
    sign_in identities(:outsider)

    get household_root_path(household_id: households(:home))

    assert_response :not_found
  end

  test "a former (inactive) member gets 404" do
    sign_in identities(:former)

    get household_root_path(household_id: households(:home))

    assert_response :not_found
  end

  test "a household_id that isn't a UUID gets 404" do
    sign_in identities(:head)

    get "/not-a-household"

    assert_response :not_found
  end

  private
    def assert_two_columns
      assert_response :success
      assert_select ".blankslate", count: 0
      assert_select "main", text: /Welcome to/, count: 0
      assert_select "main .Layout-main", text: /Next family study/
      assert_select "main .Layout-sidebar" do
        assert_select "h2", "Family goals"
        assert_select "h2", "Mine · follows you to every household"
        assert_select "h3", "My goals"
        assert_select "h3", "Recent meeting notes"
      end
    end

    def session_path(study_session)
      household_family_study_session_path(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)
    end

    def with_nothing_to_show
      households(:home).family_studies.destroy_all
      with_no_goals_or_notes
    end

    def with_no_goals_or_notes
      Goal.destroy_all
      MeetingNote.destroy_all
    end

    def add_goals(owner, count, set_by: users(:spouse))
      count.times.map { owner.goals.create!(title: "Goal #{it}", target_on: Date.new(2027, 6, 1) + it, set_by:) }
    end

    def goal_path(goal)
      household_goal_path(household_id: households(:home), id: goal)
    end

    def queries_during_get
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[ SCHEMA TRANSACTION ]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get household_root_path(household_id: households(:home)) }
      count
    end

    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
