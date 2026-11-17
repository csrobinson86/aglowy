require "application_system_test_case"

# Children's avatars, set by heads and adults in Settings → Children (docs/design/avatars.md, Children's avatars; frames
# settings-children-avatars.png and child-avatar-preview.png), so a child without a login gets one too.
class ChildrenAvatarsTest < ApplicationSystemTestCase
  setup do
    users(:eli).change_avatar_color("orange")
    sign_in identities(:spouse)
    visit household_settings_children_url(household_id: households(:home))
  end

  test "an adult sets Sofia's photo from Settings → Children; Members shows it" do
    within("#children-avatars li", text: "Eli Child") { assert_text "Signs in as eli.rivera · can change it too" }
    within("#children-avatars li", text: "Sofia Child") { assert_text "No login" }
    assert_accessible
    capture_screens("settings-children-avatars")

    within("#children-avatars li", text: "Sofia Child") { click_on "Change avatar" }
    within("dialog", text: "Avatar for Sofia") do
      assert_selector ".avatar-initial--blue.avatar-initial--size-80", text: "S"
      assert_button "Upload photo"
      assert_no_button "Remove photo"
      assert_selector "fieldset legend", text: "Color for Sofia's initial"
      attach_file(file_fixture("avatars/photo.png")) { click_on "Upload photo" }
    end

    within("dialog[open]", text: "Avatar for Sofia") do
      assert_selector "img.avatar-preview__photo[src^='blob:']"
      assert_text "photo.png · 1 KB"
      assert_text "Everyone in Sofia's households will see it."
    end
    assert_selector "dialog[open]", count: 1
    capture_screens("child-avatar-preview")
    click_on "Save avatar"

    assert_text "Sofia's avatar is saved."
    within("#children-avatars li", text: "Sofia Child") { assert_selector "img.avatar[src*='/avatar?v='][alt='']" }

    visit household_members_url(household_id: households(:home))
    assert_selector "main img.avatar[src*='/people/#{users(:sofia).id}/avatar?v=']"
  end

  test "assert_accessible with the dialog open, then pick a color for Sofia's initial" do
    within("#children-avatars li", text: "Sofia Child") { click_on "Change avatar" }

    within("dialog[open]", text: "Avatar for Sofia") do
      assert_selector ".color-picker__chosen", text: "Blue"
      assert_accessible
      capture_screens("child-avatar-dialog")
      find("label[for=child_avatar_color_#{users(:sofia).id}_green]").click
      assert_selector ".color-picker__chosen", text: "Green"
      click_on "Save color"
    end

    assert_text "Sofia's avatar is saved."
    within("#children-avatars li", text: "Sofia Child") { assert_selector ".avatar-initial--green", text: "S" }
  end

  test "remove Sofia's photo; her initial is back" do
    users(:sofia).change_avatar(Rack::Test::UploadedFile.new(file_fixture("avatars/photo.png")))
    visit household_settings_children_url(household_id: households(:home))

    within("#children-avatars li", text: "Sofia Child") { click_on "Change avatar" }
    within("dialog[open]", text: "Avatar for Sofia") { click_on "Remove photo" }

    assert_text "Sofia's photo is removed."
    within("#children-avatars li", text: "Sofia Child") { assert_selector ".avatar-initial", text: "S" }
  end
end
