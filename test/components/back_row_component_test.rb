require "test_helper"

# An inner page's back row on a phone (docs/design/phone.md, The rules: 2): "‹ <parent>" on the left and the page's
# "…" at the right end. Hidden from md up, where the breadcrumbs show instead.
class BackRowComponentTest < ViewComponent::TestCase
  test "renders the link with its label and href" do
    render_inline(BackRowComponent.new(href: "/goals", label: "My goals"))

    assert_selector "a[href='/goals']", count: 1
    assert_selector "a[href='/goals'] svg.octicon-chevron-left", count: 1
    assert_equal "My goals", page.find("a[href='/goals']").text.strip
  end

  test "renders the menu slot" do
    render_inline(BackRowComponent.new(href: "/goals", label: "My goals")) do |row|
      row.with_menu { "<button aria-label='Goal actions'></button>".html_safe }
    end

    assert_selector ".back-row__menu button[aria-label='Goal actions']", count: 1
  end

  test "the with-menu preview shows its menu's button" do
    render_preview(:with_menu)

    assert_selector ".back-row__menu button[aria-label='Goal actions']", count: 1
  end

  test "renders no menu container without one" do
    render_inline(BackRowComponent.new(href: "/goals", label: "My goals"))

    assert_selector ".back-row", count: 1
    assert_no_selector ".back-row__menu"
  end

  test "is d-md-none" do
    render_inline(BackRowComponent.new(href: "/goals", label: "My goals"))

    assert_selector ".back-row.d-flex.d-md-none", count: 1
  end
end
