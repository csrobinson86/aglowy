require "test_helper"

# The Two flames mark, with or without the word "Aglowy" (docs/design/brand.md, Where it appears).
class LogoComponentTest < ViewComponent::TestCase
  test "medium, the default: the mark at 24 px, hidden from screen readers, beside the word Aglowy" do
    render_inline(LogoComponent.new(href: "/somewhere"))

    assert_selector "a[href='/somewhere']", count: 1
    assert_selector "a[href='/somewhere'] img[src*='aglowy-mark'][src$='.svg'][alt=''][width='24'][height='24']", count: 1
    assert_equal "Aglowy", page.find("a[href='/somewhere']").text.strip
  end

  test "large: the mark alone at 48 px, named Aglowy, with no other text" do
    render_inline(LogoComponent.new(href: "/somewhere", size: :large))

    assert_selector "a[href='/somewhere'] img[src*='aglowy-mark'][src$='.svg'][alt='Aglowy'][width='48'][height='48']", count: 1
    assert_equal "", page.find("a[href='/somewhere']").text.strip
  end

  test "an unknown size raises" do
    assert_raises(ArgumentError) { LogoComponent.new(href: "/somewhere", size: :small) }
  end
end
