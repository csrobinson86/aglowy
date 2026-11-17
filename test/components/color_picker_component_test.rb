require "test_helper"

# The color picker, the approved hand-built radio group drawn as swatches, for notes and avatars (CLAUDE.md, Forms;
# docs/design/notes.md, Colors; docs/design/avatars.md, The Avatar box).
class ColorPickerComponentTest < ViewComponent::TestCase
  test "notes' colors with none: seven labelled radios in a fieldset with the legend Color, the chosen one checked and named" do
    render_inline(ColorPickerComponent.new(name: "personal_note[color]", selected: "yellow", colors: PersonalNote.colors.keys, legend: "Color", legend_beside: true))

    assert_selector "fieldset legend.color-picker__legend--beside", text: "Color"
    assert_selector "input[type=radio][name='personal_note[color]']", count: 7, visible: :all
    %w[ None Yellow Green Blue Purple Pink Orange ].each do |name|
      radio = page.find("input[type=radio][value='#{name.downcase}']", visible: :all)
      assert_equal "personal_note_color_#{name.downcase}", radio[:id]
      assert_selector "label[for='#{radio[:id]}'].color-picker__swatch--#{name.downcase}", text: name, visible: :all
    end
    assert_selector "input[type=radio][value=yellow][checked]", visible: :all
    assert_selector "input[type=radio][checked]", count: 1, visible: :all
    assert_selector ".color-picker__chosen", text: "Yellow"
    assert_no_selector ".color-picker__swatch--labelled", visible: :all
  end

  test "no note color is None" do
    render_inline(ColorPickerComponent.new(name: "personal_note[color]", selected: "none", colors: PersonalNote.colors.keys, legend: "Color"))

    assert_selector "input[type=radio][value=none][checked]", visible: :all
    assert_selector ".color-picker__chosen", text: "None"
  end

  test "the avatar palette with the initial in each swatch, the chosen color checked and named" do
    render_inline(ColorPickerComponent.new(name: "avatar[color]", selected: "green", colors: Avatar::Palette::COLORS, legend: "Color for your initial", swatch_label: "M"))

    assert_selector "fieldset legend", text: "Color for your initial"
    assert_no_selector ".color-picker__legend--beside"
    assert_selector "input[type=radio][name='avatar[color]']", count: 6, visible: :all
    %w[ Blue Green Purple Pink Orange Yellow ].each do |name|
      label = page.find("label[for='avatar_color_#{name.downcase}'].color-picker__swatch--labelled.color-picker__swatch--#{name.downcase}", visible: :all)
      assert_equal name, label.find(".sr-only", visible: :all).text
      assert_equal "M", label.find("[aria-hidden=true]", visible: :all).text
    end
    assert_selector "input[type=radio][value=green][checked]", visible: :all
    assert_selector "input[type=radio][checked]", count: 1, visible: :all
    assert_selector ".color-picker__chosen", text: "Green"
  end

  # Settings → Children has a picker per child, all named avatar[color].
  test "id_prefix keeps each picker's ids apart under one name" do
    render_inline(ColorPickerComponent.new(name: "avatar[color]", selected: "blue", colors: Avatar::Palette::COLORS, legend: "Color", id_prefix: "child_avatar_color_1"))

    assert_selector "input#child_avatar_color_1_blue[name='avatar[color]'][checked]", visible: :all
    assert_selector "label[for=child_avatar_color_1_blue]", visible: :all
  end
end
