require "test_helper"

# Settings → Household: the household's name and time zone, heads only (docs/design/settings.md, Sections and who sees them).
class Settings::HouseholdsControllerTest < ActionDispatch::IntegrationTest
  setup { @home = households(:home) }

  test "a head sees the Household section with its form and the household group in the nav" do
    sign_in identities(:head)

    get household_settings_household_path(household_id: @home)

    assert_response :success
    assert_select "title", "Household · Settings · The Head Family · Aglowy"
    assert_select "main h1", "Settings"
    assert_select "main h2", "Household"
    assert_select "main p", "The Head Family · heads can change this."
    assert_select "nav[aria-label='Settings'] a[aria-current=page]", "Household"
    assert_select "nav[aria-label='Main settings'] a[aria-current=page]", "Settings"
    assert_select "form[action=?] #household_name[value=?]", household_settings_household_path(household_id: @home), "The Head Family"
    assert_select "#household_time_zone option[selected][value=?]", "UTC"
  end

  test "a head renames the household and comes back to Household" do
    sign_in identities(:head)

    patch household_settings_household_path(household_id: @home), params: { household: { name: "The Riveras", time_zone: "Central Time (US & Canada)" } }

    assert_redirected_to household_settings_household_path(household_id: @home)
    assert_equal "Household settings saved.", flash[:notice]
    assert_equal [ "The Riveras", "Central Time (US & Canada)" ], [ @home.reload.name, @home.time_zone ]
  end

  test "a head changing the time zone keeps each study at the same local time" do
    sign_in identities(:head)
    session = family_study_sessions(:weekly_next)
    local = session.local_scheduled_at.strftime("%Y-%m-%d %H:%M")

    patch household_settings_household_path(household_id: @home), params: { household: { name: "The Head Family", time_zone: "Tokyo" } }

    assert_equal local, session.reload.local_scheduled_at.strftime("%Y-%m-%d %H:%M")
    assert_equal "Tokyo", session.family_study.household.time_zone
  end

  test "a refused save re-renders Household with 422, and the page keeps the saved name" do
    sign_in identities(:head)

    patch household_settings_household_path(household_id: @home), params: { household: { name: " ", time_zone: "Atlantis" } }

    assert_response :unprocessable_content
    assert_select "main h2", "Household"
    assert_select "#household_name[aria-invalid=true]"
    assert_select "#household_time_zone[aria-invalid=true]"
    assert_select "title", "Household · Settings · The Head Family · Aglowy"
    assert_equal [ "The Head Family", "UTC" ], [ @home.reload.name, @home.time_zone ]
  end

  test "an adult and a child are refused, to see it or to save it" do
    %i[ spouse eli ].each do |identity|
      sign_in identities(identity)

      get household_settings_household_path(household_id: @home)
      assert_redirected_to household_root_path(household_id: @home)

      patch household_settings_household_path(household_id: @home), params: { household: { name: "Taken Over", time_zone: "Tokyo" } }
      assert_redirected_to household_root_path(household_id: @home)
      assert_equal "You can't do that in this household.", flash[:alert]
      assert_equal [ "The Head Family", "UTC" ], [ @home.reload.name, @home.time_zone ]
    end
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)
    get household_settings_household_path(household_id: @home)
    assert_response :not_found

    sign_in identities(:outsider) # A raised 404 doesn't write the session cookie.
    patch household_settings_household_path(household_id: @home), params: { household: { name: "Taken Over", time_zone: "Tokyo" } }
    assert_response :not_found
    assert_equal "The Head Family", @home.reload.name
  end

  test "a signed-out visitor is sent to sign in" do
    get household_settings_household_path(household_id: @home)

    assert_redirected_to new_identity_session_path
  end
end
