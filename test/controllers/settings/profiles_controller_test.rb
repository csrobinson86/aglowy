require "test_helper"

# Settings → Profile (docs/design/settings.md, Pages and routes): the person's own name and time zone, from any household.
class Settings::ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup { @home = households(:home) }

  test "GET /:household_id/settings opens Profile" do
    sign_in identities(:head)

    get household_settings_path(household_id: @home)

    assert_redirected_to household_settings_profile_path(household_id: @home)
  end

  test "a head, an adult and a child see their own Profile in the household layout, with the section nav" do
    { head: "Hannah Head", spouse: "Sam Spouse", eli: "Eli Child" }.each do |identity, name|
      sign_in identities(identity)

      get household_settings_profile_path(household_id: @home)

      assert_response :success
      assert_select "title", "Profile · Settings · The Head Family · Aglowy"
      assert_select "main h1", "Settings"
      assert_select "main h2", "Profile"
      assert_select "main", text: /Follows you to every household\./
      assert_select "nav[aria-label='Settings'] a[aria-current=page]", "Profile"
      assert_select "nav[aria-label='Main settings'] a[aria-current=page]", "Settings"
      assert_select "form[action=?] #user_name[value=?]", household_settings_profile_path(household_id: @home), name
    end
  end

  test "a head, an adult and a child save their name and time zone and come back to Profile" do
    %i[ head spouse eli ].each do |identity|
      sign_in identities(identity)

      patch household_settings_profile_path(household_id: @home), params: { user: { name: "  New   Name ", time_zone: "Central Time (US & Canada)" } }

      assert_redirected_to household_settings_profile_path(household_id: @home)
      assert_equal "Your profile is saved.", flash[:notice]
      user = identities(identity).user.reload
      assert_equal [ "New Name", "Central Time (US & Canada)" ], [ user.name, user.time_zone ]
    end
  end

  test "a refused save re-renders Profile with 422, for a head, an adult and a child, and the sidebar keeps the saved name" do
    { head: "Hannah Head", spouse: "Sam Spouse", eli: "Eli Child" }.each do |identity, name|
      sign_in identities(identity)

      patch household_settings_profile_path(household_id: @home), params: { user: { name: " ", time_zone: "Atlantis" } }

      assert_response :unprocessable_content
      assert_select "main h2", "Profile"
      assert_select "#user_name[aria-invalid=true]"
      assert_select "#user_time_zone[aria-invalid=true]"
      assert_select "aside", text: /#{name}/
      assert_equal name, identities(identity).user.reload.name
    end
  end

  test "only name and time zone are permitted" do
    sign_in identities(:head)

    patch household_settings_profile_path(household_id: @home), params: { user: { name: "Hannah Head", appearance: "dark" } }

    assert_equal "auto", users(:head).reload.appearance
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)
    get household_settings_profile_path(household_id: @home)
    assert_response :not_found

    sign_in identities(:outsider)
    patch household_settings_profile_path(household_id: @home), params: { user: { name: "Taken Over" } }
    assert_response :not_found
    assert_equal "Olive Outsider", users(:outsider).reload.name
  end

  test "a signed-out visitor is sent to sign in" do
    get household_settings_profile_path(household_id: @home)
    assert_redirected_to new_identity_session_path

    patch household_settings_profile_path(household_id: @home), params: { user: { name: "Someone" } }
    assert_redirected_to new_identity_session_path
  end
end
