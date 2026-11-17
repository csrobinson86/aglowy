require "test_helper"

# Settings → Children → "Children's avatars": heads and adults set a child's photo and color, so a child without a
# login gets one too (docs/design/avatars.md, Children's avatars).
class Settings::Children::AvatarsControllerTest < ActionDispatch::IntegrationTest
  setup { @home = households(:home) }

  test "a head and an adult see Children's avatars first, a row per child with how they sign in" do
    %i[ head spouse ].each do |identity|
      sign_in identities(identity)

      get household_settings_children_path(household_id: @home)

      assert_response :success
      assert_select "main .Box-title", count: 2 do |titles|
        assert_equal [ "Children's avatars", "Children" ], titles.map(&:text).map(&:strip)
      end
      assert_select "#children-avatars" do
        assert_select "li", text: /Eli Child\s+Signs in as eli.rivera · can change it too/
        assert_select "li", text: /Sofia Child\s+No login/
        assert_select "button", text: /Change avatar/, count: 3
        assert_select "dialog", text: /Avatar for Sofia/
        assert_select "form[action=?] input[type=file][name='avatar[photo]']", household_settings_child_avatar_path(household_id: @home, child_id: users(:sofia))
        assert_select "form[action=?] input[type=radio][name='avatar[color]'][value=blue][checked]", household_settings_child_avatar_path(household_id: @home, child_id: users(:sofia))
        assert_select "p", "A child's avatar follows them to every household they're in. Children who sign in can change their own in Settings → Profile."
      end
    end
  end

  test "an adult sets a child's photo and color, and removes the photo" do
    sign_in identities(:spouse)
    sofia = users(:sofia)

    patch household_settings_child_avatar_path(household_id: @home, child_id: sofia), params: { avatar: { color: "pink" } }

    assert_redirected_to household_settings_children_path(household_id: @home)
    assert_equal "Sofia's avatar is saved.", flash[:notice]
    assert_equal "pink", sofia.reload.avatar_color

    patch household_settings_child_avatar_path(household_id: @home, child_id: sofia), params: { avatar: { photo: photo("gps.jpg") } }

    assert_redirected_to household_settings_children_path(household_id: @home)
    assert_equal "Sofia's avatar is saved.", flash[:notice]
    assert_equal "image/webp", sofia.reload.avatar.content_type
    follow_redirect!
    assert_select "#children-avatars img.avatar[src=?]", Rails.application.routes.url_helpers.avatar_path(sofia, v: sofia.avatar.blob.checksum)
    assert_select "#children-avatars form[action=?] button.Button--danger", household_settings_child_avatar_path(household_id: @home, child_id: sofia), "Remove photo"

    delete household_settings_child_avatar_path(household_id: @home, child_id: sofia)

    assert_redirected_to household_settings_children_path(household_id: @home)
    assert_equal "Sofia's photo is removed.", flash[:notice]
    assert_not sofia.reload.avatar.attached?
  end

  test "a refused photo or color re-renders Children with the reason on the child's row and saves nothing" do
    sign_in identities(:head)

    patch household_settings_child_avatar_path(household_id: @home, child_id: users(:eli)), params: { avatar: { photo: photo("document.jpg") } }

    assert_response :unprocessable_content
    assert_select "main h2", "Children"
    assert_select "#child-avatar-error-#{users(:eli).id}", "Choose a JPEG, PNG, WebP or HEIC photo up to 10 MB."
    assert_select "input[type=file][aria-describedby~=?]", "child-avatar-error-#{users(:eli).id}"
    assert_select "[id^=child-avatar-error-]", count: 1
    assert_not users(:eli).reload.avatar.attached?

    patch household_settings_child_avatar_path(household_id: @home, child_id: users(:eli)), params: { avatar: { color: "red" } }

    assert_response :unprocessable_content
    assert_select "#child-avatar-error-#{users(:eli).id}", "Avatar color is not included in the list"
    assert_select "#children-avatars .avatar-initial--blue", text: "E"
    assert_equal "blue", users(:eli).reload.avatar_color
  end

  test "an adult's id in place of a child's is a 404" do
    users(:head).change_avatar(photo("photo.png"))
    sign_in identities(:spouse)

    patch household_settings_child_avatar_path(household_id: @home, child_id: users(:head)), params: { avatar: { color: "pink" } }
    assert_response :not_found

    # A 404 doesn't keep the session.
    sign_in identities(:spouse)
    delete household_settings_child_avatar_path(household_id: @home, child_id: users(:head))
    assert_response :not_found

    assert_equal "blue", users(:head).reload.avatar_color
    assert users(:head).avatar.attached?
  end

  test "a child of another household is a 404" do
    elsewhere = User.create!(name: "Otto Other")
    households(:other).memberships.create!(user: elsewhere, role: :child)
    sign_in identities(:head)

    patch household_settings_child_avatar_path(household_id: @home, child_id: elsewhere), params: { avatar: { color: "pink" } }

    assert_response :not_found
    assert_equal "blue", elsewhere.reload.avatar_color
  end

  test "a non-member is a 404" do
    sign_in identities(:outsider)

    patch household_settings_child_avatar_path(household_id: @home, child_id: users(:sofia)), params: { avatar: { color: "pink" } }

    assert_response :not_found
    assert_equal "blue", users(:sofia).reload.avatar_color
  end

  test "a child member trying it is refused" do
    users(:sofia).change_avatar(photo("photo.png"))
    sign_in identities(:eli)

    patch household_settings_child_avatar_path(household_id: @home, child_id: users(:sofia)), params: { avatar: { color: "pink" } }

    assert_redirected_to household_root_path(household_id: @home)
    assert_equal "You can't do that in this household.", flash[:alert]

    delete household_settings_child_avatar_path(household_id: @home, child_id: users(:sofia))

    assert_redirected_to household_root_path(household_id: @home)
    assert_equal "blue", users(:sofia).reload.avatar_color
    assert users(:sofia).avatar.attached?
  end

  private
    def photo(name)
      Rack::Test::UploadedFile.new(file_fixture("avatars/#{name}"))
    end
end
