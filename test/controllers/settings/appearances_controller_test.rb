require "test_helper"

# Settings → Appearance (docs/design/app-shell.md, Theming and appearance; docs/design/settings.md).
class Settings::AppearancesControllerTest < ActionDispatch::IntegrationTest
  setup { @home = households(:home) }

  test "a head, an adult and a child see the Theme choices on Appearance" do
    %i[ head spouse eli ].each do |identity|
      sign_in identities(identity)

      get household_settings_appearance_path(household_id: @home)

      assert_response :success
      assert_select "main h2", "Appearance"
      assert_select "main", text: /Follows you to every household and device\./
      assert_select "nav[aria-label='Settings'] a[aria-current=page]", "Appearance"
      assert_select "form[action=?] input[type=radio][name='user[appearance]'][value=auto][checked]", household_settings_appearance_path(household_id: @home)
    end
  end

  test "a head, an adult and a child choose Dark and come back to Appearance, in dark" do
    %i[ head spouse eli ].each do |identity|
      sign_in identities(identity)

      patch household_settings_appearance_path(household_id: @home), params: { user: { appearance: "dark" } }

      assert_redirected_to household_settings_appearance_path(household_id: @home)
      assert_equal "Your appearance is saved.", flash[:notice]
      assert_equal "dark", identities(identity).user.reload.appearance

      follow_redirect!
      assert_select "body[data-color-mode=dark]"
    end
  end

  test "a refused save re-renders Appearance with 422, for a head, an adult and a child, and saves nothing" do
    %i[ head spouse eli ].each do |identity|
      sign_in identities(identity)

      patch household_settings_appearance_path(household_id: @home), params: { user: { appearance: "sepia" } }

      assert_response :unprocessable_content
      assert_select "main h2", "Appearance"
      assert_select "main", text: /is not included in the list/
      assert_select "body[data-color-mode=auto]"
      assert_equal "auto", identities(identity).user.reload.appearance
    end
  end

  test "only appearance is permitted" do
    sign_in identities(:head)

    patch household_settings_appearance_path(household_id: @home), params: { user: { appearance: "dark", name: "Someone Else" } }

    assert_equal [ "dark", "Hannah Head" ], [ users(:head).reload.appearance, users(:head).name ]
  end

  test "a non-member gets a 404" do
    sign_in identities(:outsider)
    get household_settings_appearance_path(household_id: @home)
    assert_response :not_found

    sign_in identities(:outsider)
    patch household_settings_appearance_path(household_id: @home), params: { user: { appearance: "dark" } }
    assert_response :not_found
    assert_equal "auto", users(:outsider).reload.appearance
  end
end
