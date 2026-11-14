require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "a visitor is redirected to sign in" do
    get household_root_path(household_id: households(:home))

    assert_redirected_to new_identity_session_path
  end

  test "a member sees the Home header with the household name, and the member list has moved to Members" do
    without_family_studies
    sign_in identities(:spouse)

    get household_root_path(household_id: households(:home))

    assert_response :success
    assert_select "h1", "Home"
    assert_select ".Subhead-description", "The Head Family"
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

  test "a head sees Add a member" do
    without_family_studies
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".blankslate p", "Add the people in your household. Family studies, goals and notes will show up here as you add them."
    assert_select ".blankslate a[href='#{new_household_member_path(household_id: households(:home))}']", "Add a member"
  end

  test "an adult and a child don't see Add a member" do
    without_family_studies
    [ identities(:spouse), child_identity ].each do |identity|
      sign_in identity

      get household_root_path(household_id: households(:home))

      assert_response :success
      assert_select ".blankslate p", "Family studies, goals and notes will show up here."
      assert_select "a", { text: "Add a member", count: 0 }, "expected #{identity.email} not to see Add a member"
    end
  end

  test "a head's empty state offers Schedule a study first, then Add a member" do
    without_family_studies
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".blankslate a.Button--primary[href='#{new_household_family_study_path(household_id: households(:home))}']", "Schedule a study"
    assert_select ".blankslate a:not(.Button--primary)[href='#{new_household_member_path(household_id: households(:home))}']", "Add a member"
  end

  test "an adult's empty state offers Schedule a study; a child's offers nothing" do
    without_family_studies
    sign_in identities(:spouse)
    get household_root_path(household_id: households(:home))
    assert_select ".blankslate a[href='#{new_household_family_study_path(household_id: households(:home))}']", "Schedule a study"

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
    def session_path(study_session)
      household_family_study_session_path(household_id: households(:home), family_study_id: study_session.family_study, id: study_session)
    end

    def without_family_studies
      households(:home).family_studies.destroy_all
    end

    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
