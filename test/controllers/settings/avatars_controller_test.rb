require "test_helper"

# Settings → Profile's Avatar box: your own initial's color (docs/design/avatars.md, Pages and routes).
class Settings::AvatarsControllerTest < ActionDispatch::IntegrationTest
  setup { @home = households(:home) }

  test "a head, an adult and a child see the Avatar box above Profile, with their color checked" do
    %i[ head spouse eli ].each do |identity|
      sign_in identities(identity)

      get household_settings_profile_path(household_id: @home)

      assert_response :success
      assert_select "main .Box-title", count: 2 do |titles|
        assert_equal [ "Avatar", "Profile" ], titles.map(&:text).map(&:strip)
      end
      assert_select "main .avatar-initial--size-80.avatar-initial--blue[role=img][aria-label=?]", users(identity).name
      assert_select "form[action=?] fieldset legend", household_settings_avatar_path(household_id: @home), "Color for your initial"
      assert_select "input[type=radio][name='avatar[color]'][value=blue][checked]"
      assert_select "form[action=?] button[type=submit]", household_settings_avatar_path(household_id: @home), "Save color"
    end
  end

  test "change your color, and come back to Profile with the notice" do
    sign_in identities(:head)

    patch household_settings_avatar_path(household_id: @home), params: { avatar: { color: "green" } }

    assert_redirected_to household_settings_profile_path(household_id: @home)
    assert_equal "Your avatar is saved.", flash[:notice]
    assert_equal "green", users(:head).reload.avatar_color

    follow_redirect!
    assert_select "aside .avatar-initial--green", text: "H"
    assert_select "input[type=radio][name='avatar[color]'][value=green][checked]"
  end

  test "a child changes their own color too" do
    sign_in identities(:eli)

    patch household_settings_avatar_path(household_id: @home), params: { avatar: { color: "orange" } }

    assert_redirected_to household_settings_profile_path(household_id: @home)
    assert_equal "orange", users(:eli).reload.avatar_color
  end

  test "a color outside the palette is refused with unprocessable_content and saves nothing" do
    sign_in identities(:eli)

    patch household_settings_avatar_path(household_id: @home), params: { avatar: { color: "red" } }

    assert_response :unprocessable_content
    assert_select "main h2", "Profile"
    assert_select "main", text: /Avatar color is not included in the list/
    assert_select "main .avatar-initial--blue[role=img]"
    assert_select "input[type=radio][name='avatar[color]'][value=blue][checked]"
    assert_equal "blue", users(:eli).reload.avatar_color
  end

  test "only your own: a user id in the params changes nobody else" do
    sign_in identities(:head)

    patch household_settings_avatar_path(household_id: @home), params: { avatar: { color: "pink", user_id: users(:eli).id }, user_id: users(:eli).id }

    assert_equal [ "pink", "blue" ], [ users(:head).reload.avatar_color, users(:eli).reload.avatar_color ]
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)

    patch household_settings_avatar_path(household_id: @home), params: { avatar: { color: "green" } }

    assert_response :not_found
    assert_equal "blue", users(:outsider).reload.avatar_color
  end
end
