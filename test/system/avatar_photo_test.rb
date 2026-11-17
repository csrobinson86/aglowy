require "application_system_test_case"

# A photo for your avatar (docs/design/avatars.md, The Avatar box and The preview dialog; frames avatar-preview.png,
# settings-avatar-photo.png and phone-avatar.png): choose a photo, see how it'll look, save it, and it shows wherever
# you do.
class AvatarPhotoTest < ApplicationSystemTestCase
  setup do
    sign_in identities(:head)
    visit household_settings_profile_url(household_id: households(:home))
  end

  test "choose a photo, see the preview, save; the sidebar shows it" do
    within("aside") { assert_selector ".avatar-initial", text: "H" }

    attach_file(file_fixture("avatars/photo.png")) { click_on "Upload photo" }

    within("dialog", text: "New avatar") do
      assert_selector "img.avatar-preview__photo[src^='blob:']"
      assert_text "photo.png · 1 KB"
      assert_text "This is how it will look. Aglowy keeps the middle as a square and removes the photo's location and camera details. Everyone in your households will see it."
      assert_button "Choose another photo"
      assert_button "Cancel"
    end
    assert_accessible
    capture_screens("avatar-preview")
    click_on "Save avatar"

    assert_text "Your avatar is saved."
    within("aside") { assert_selector "img.avatar[src*='/avatar?v='][alt='']" }
    assert_selector "main img.avatar[alt='Hannah Head']"
    assert_button "Change photo"
    assert_button "Remove photo"
    assert_no_text "Color for your initial"
    assert_accessible
    capture_screens("settings-avatar-photo")
    capture_screens("phone-avatar", viewports: { phone: ScreenshotHelper::VIEWPORTS[:phone] })
  end

  test "remove it; the initial is back" do
    users(:head).change_avatar(Rack::Test::UploadedFile.new(file_fixture("avatars/photo.png")))
    visit household_settings_profile_url(household_id: households(:home))
    within("aside") { assert_selector "img.avatar" }

    click_on "Remove photo"

    assert_text "Your photo is removed."
    within("aside") { assert_selector ".avatar-initial", text: "H" }
    assert_button "Upload photo"
    assert_text "Color for your initial"
  end

  test "a photo the browser can't draw: the preview says so, and Save still works" do
    attach_file(file_fixture("avatars/photo.heic")) { click_on "Upload photo" }

    within("dialog", text: "New avatar") do
      assert_text "Preview not available for this photo. It will be cropped the same way."
      assert_no_selector "img.avatar-preview__photo"
      click_on "Save avatar"
    end

    assert_text "Your avatar is saved."
    within("aside") { assert_selector "img.avatar" }
  end

  test "over 10 MB: the error at once, with Save disabled; Cancel saves nothing" do
    Tempfile.create([ "big-photo", ".jpg" ]) do |file|
      file.binmode
      file.write(file_fixture("avatars/gps.jpg").binread)
      file.write("\0" * (11.megabytes - file.size))
      file.flush

      attach_file(file.path) { click_on "Upload photo" }

      within("dialog", text: "New avatar") do
        assert_text "Choose a JPEG, PNG, WebP or HEIC photo up to 10 MB."
        assert_button "Save avatar", disabled: true
        click_on "Cancel"
      end
    end

    assert_no_selector "dialog[open]"
    within("aside") { assert_selector ".avatar-initial", text: "H" }
  end
end
