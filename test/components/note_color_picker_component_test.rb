require "test_helper"

class NoteColorPickerComponentTest < ViewComponent::TestCase
  test "seven labelled radios in a fieldset with the legend Color, the chosen one checked, its name shown" do
    render_inline(NoteColorPickerComponent.new(name: "personal_note[color]", selected: "yellow"))

    assert_selector "fieldset legend", text: "Color"
    assert_selector "input[type=radio][name='personal_note[color]']", count: 7, visible: :all
    %w[ None Yellow Green Blue Purple Pink Orange ].each do |name|
      radio = page.find("input[type=radio][value='#{name.downcase}']", visible: :all)
      assert_selector "label[for='#{radio[:id]}']", text: name, visible: :all
    end
    assert_selector "input[type=radio][value=yellow][checked]", visible: :all
    assert_selector "input[type=radio][checked]", count: 1, visible: :all
    assert_selector ".note-color-picker__chosen", text: "Yellow"
  end

  test "no color is None" do
    render_inline(NoteColorPickerComponent.new(name: "personal_note[color]", selected: "none"))

    assert_selector "input[type=radio][value=none][checked]", visible: :all
    assert_selector ".note-color-picker__chosen", text: "None"
  end
end
