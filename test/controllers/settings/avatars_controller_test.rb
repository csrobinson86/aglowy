require "test_helper"

# Settings → Profile's Avatar box: your own photo and your initial's color (docs/design/avatars.md, Pages and routes).
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

  test "with no photo: Upload photo, the captions and the color picker, and no Remove photo" do
    sign_in identities(:head)

    get household_settings_profile_path(household_id: @home)

    assert_select "form[action=?][enctype='multipart/form-data']", household_settings_avatar_path(household_id: @home) do
      assert_select "label[for=avatar_photo]", "Avatar photo"
      assert_select "input#avatar_photo[type=file][name='avatar[photo]'][accept='image/jpeg,image/png,image/webp,image/heic,image/heif']"
      assert_select "button[type=button]", "Upload photo"
    end
    assert_select "main", text: /JPEG, PNG, WebP or HEIC, up to 10 MB. Aglowy keeps the middle of the photo as a square and removes its location and camera details./
    assert_select "main", text: /Everyone in your households sees your avatar./
    assert_select "button", text: "Remove photo", count: 0
    assert_select "fieldset legend", "Color for your initial"
  end

  test "upload a photo, and come back to Profile with it, Change photo and Remove photo, and no color picker" do
    sign_in identities(:head)

    patch household_settings_avatar_path(household_id: @home), params: { avatar: { photo: photo("gps.jpg") } }

    assert_redirected_to household_settings_profile_path(household_id: @home)
    assert_equal "Your avatar is saved.", flash[:notice]
    avatar = users(:head).reload.avatar
    assert_equal "image/webp", avatar.content_type

    follow_redirect!
    # One URL in every household: no household_id in it.
    src = Rails.application.routes.url_helpers.avatar_path(users(:head), v: avatar.blob.checksum)
    assert_select "aside img.avatar[src=?][alt='']", src
    assert_select "main img.avatar[src=?][alt='Hannah Head'][width=80]", src
    assert_select "button", "Change photo"
    assert_select "form[action=?] input[name=_method][value=delete]", household_settings_avatar_path(household_id: @home)
    assert_select "button.Button--danger", "Remove photo"
    assert_select "fieldset legend", text: "Color for your initial", count: 0
  end

  test "a refused photo re-renders Profile with the message under the picker and stores nothing" do
    sign_in identities(:eli)

    assert_no_difference -> { ActiveStorage::Blob.count } do
      patch household_settings_avatar_path(household_id: @home), params: { avatar: { photo: photo("document.jpg") } }
    end

    assert_response :unprocessable_content
    assert_select "main h2", "Profile"
    assert_select "#avatar_photo_error", "Choose a JPEG, PNG, WebP or HEIC photo up to 10 MB."
    assert_select "input#avatar_photo[aria-describedby~=avatar_photo_error]"
    assert_select "main .avatar-initial--size-80"
    assert_not users(:eli).reload.avatar.attached?
  end

  test "remove your photo, and come back to Profile with the notice and your initial" do
    users(:head).change_avatar(photo("photo.png"))
    sign_in identities(:head)

    delete household_settings_avatar_path(household_id: @home)

    assert_redirected_to household_settings_profile_path(household_id: @home)
    assert_equal "Your photo is removed.", flash[:notice]
    assert_not users(:head).reload.avatar.attached?
    follow_redirect!
    assert_select "aside .avatar-initial", text: "H"
  end

  test "removing only ever removes your own photo" do
    users(:eli).change_avatar(photo("photo.png"))
    sign_in identities(:head)

    delete household_settings_avatar_path(household_id: @home), params: { user_id: users(:eli).id }

    assert users(:eli).reload.avatar.attached?
  end

  test "a non-member can't remove a photo: 404" do
    users(:outsider).change_avatar(photo("photo.png"))
    sign_in identities(:outsider)

    delete household_settings_avatar_path(household_id: @home)

    assert_response :not_found
    assert users(:outsider).reload.avatar.attached?
  end

  private
    def photo(name)
      Rack::Test::UploadedFile.new(file_fixture("avatars/#{name}"))
    end
end
