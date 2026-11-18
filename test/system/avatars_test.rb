require "application_system_test_case"

# Your initial in a color you pick, everywhere you show (docs/design/avatars.md; frames settings-avatar.png,
# members-avatars.png and child-profile-avatar.png).
class AvatarsTest < ApplicationSystemTestCase
  test "pick green in Settings → Profile, and the sidebar shows the green initial" do
    sign_in identities(:head)
    visit household_settings_profile_url(household_id: households(:home))

    within("aside") { assert_selector ".avatar-initial--blue", text: "H" }
    within("fieldset", text: "Color for your initial") do
      assert_selector ".color-picker__chosen", text: "Blue"
      find("label[for=avatar_color_green]").click
      assert_selector ".color-picker__chosen", text: "Green"
    end
    click_on "Save color"

    assert_text "Your avatar is saved."
    within("aside") { assert_selector ".avatar-initial--green", text: "H" }
    assert_selector "main .avatar-initial--green.avatar-initial--size-80[role=img][aria-label='Hannah Head']"
    assert find_field("Green", visible: :all).checked?
    assert_accessible
    capture_screens("settings-avatar")
  end

  # Notes' nine colors draw a note's swatches; an avatar's keep Primer's colors and recolor no note card
  # (docs/design/avatars.md, The Avatar box).
  test "the avatar picker keeps Primer's colors next to the notes' new ones" do
    sign_in identities(:head)
    visit household_settings_profile_url(household_id: households(:home))

    Avatar::Palette::COLORS.each do |color|
      assert_equal computed_color("var(--display-#{color}-bgColor-muted)"), background_color("label[for=avatar_color_#{color}]")
    end
    find("label[for=avatar_color_orange]").click
    within("fieldset", text: "Color for your initial") { assert_selector ".color-picker__chosen", text: "Orange" }
    assert_no_selector ".note-card"
    assert_equal computed_color("var(--display-orange-bgColor-muted)"), background_color("label[for=avatar_color_orange]")
  end

  test "a child picks their own color with the keyboard" do
    sign_in identities(:eli)
    visit household_settings_profile_url(household_id: households(:home))

    find("input[type=radio][value=blue]", visible: :all).send_keys(:right)
    within("fieldset", text: "Color for your initial") { assert_selector ".color-picker__chosen", text: "Green" }
    click_on "Save color"

    assert_text "Your avatar is saved."
    within("aside") { assert_selector ".avatar-initial--green", text: "E" }
    assert_accessible
    capture_screens("child-profile-avatar")
  end

  test "each person's own color on Members and Settings → Members and roles" do
    users(:spouse).change_avatar_color("purple")
    users(:eli).change_avatar_color("orange")
    sign_in identities(:head)

    visit household_members_url(household_id: households(:home))
    assert_selector "main .avatar-initial--purple", text: "S"
    assert_selector "main .avatar-initial--orange", text: "E"
    assert_accessible

    visit household_settings_members_url(household_id: households(:home))
    assert_selector "main .avatar-initial--purple", text: "S"
    assert_selector "main .avatar-initial--orange", text: "E"
    assert_accessible
    capture_screens("members-avatars")
  end
end
