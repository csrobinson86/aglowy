require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "a visitor is redirected to sign in" do
    get household_root_path(household_id: households(:home))

    assert_redirected_to new_identity_session_path
  end

  test "a member sees the Home header with the household name, and the member list has moved to Members" do
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
    sign_in identities(:head)

    get household_root_path(household_id: households(:home))

    assert_select ".blankslate p", "Add the people in your household. Family studies, goals and notes will show up here as you add them."
    assert_select ".blankslate a[href='#{new_household_member_path(household_id: households(:home))}']", "Add a member"
  end

  test "an adult and a child don't see Add a member" do
    [ identities(:spouse), child_identity ].each do |identity|
      sign_in identity

      get household_root_path(household_id: households(:home))

      assert_response :success
      assert_select ".blankslate p", "Family studies, goals and notes will show up here."
      assert_select "a", { text: "Add a member", count: 0 }, "expected #{identity.email} not to see Add a member"
    end
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
    def child_identity
      Identity.create!(user: users(:child), email: "child@example.com", password: "password123", confirmed_at: Time.current)
    end
end
