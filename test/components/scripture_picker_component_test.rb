require "test_helper"

class ScripturePickerComponentTest < ViewComponent::TestCase
  test "renders hidden, with the JSON for 66 books" do
    render_inline(ScripturePickerComponent.new)

    picker = page.find("[role=dialog]", visible: :hidden)
    assert picker.matches_css?("[hidden]", visible: :hidden)
    assert_equal "scripture-picker", picker["data-controller"]
    canon = JSON.parse(page.find("script[type='application/json']", visible: :all).text(:all))
    assert_equal 66, canon.size
    assert_equal({ "number" => 19, "name" => "Psalms", "single" => "Psalm" }, canon[18].slice("number", "name", "single"))
    assert_equal 150, canon[18]["verses"].size
    assert_equal 40, canon[18]["verses"][36]
    assert_equal({ "8" => 12 }, canon[42]["first_verses"])
  end

  test "the templates are present" do
    render_inline(ScripturePickerComponent.new)

    assert_selector "template[data-scripture-picker-target=bookTemplate]", visible: :all
    assert_selector "template[data-scripture-picker-target=numberTemplate]", visible: :all
    html = Nokogiri::HTML5(rendered_content)
    assert html.at("template[data-scripture-picker-target=bookTemplate] li[role=option][aria-selected=false]")
    assert html.at("template[data-scripture-picker-target=numberTemplate] button[type=button][aria-pressed=false]")
  end

  test "the header, the three regions and the footer" do
    render_inline(ScripturePickerComponent.new)

    assert_selector "button[aria-label=Back]", visible: :hidden
    assert_selector "button[aria-label=Close]", visible: :hidden
    assert_selector "[role=listbox]", visible: :hidden
    assert_selector "[role=group][aria-labelledby]", count: 2, visible: :hidden
    assert_selector "[aria-live=polite]", visible: :hidden
    assert_selector "[data-scripture-picker-url-value='/scriptures/:id']", visible: :hidden
  end

  test "Cancel and Insert are Primer buttons" do
    render_inline(ScripturePickerComponent.new)

    assert_selector "button.Button.Button--secondary[type=button]", text: "Cancel", visible: :hidden
    assert_selector "button.Button.Button--primary[type=button][disabled]", text: "Insert", visible: :hidden
  end
end
