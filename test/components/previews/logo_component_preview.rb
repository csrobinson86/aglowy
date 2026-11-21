# The logo's three sizes (docs/design/brand.md, Where it appears).
class LogoComponentPreview < ViewComponent::Preview
  # The phone top bar: the mark alone, 24 px, in a 44 px link.
  def small
    render(LogoComponent.new(href: "#", size: :small))
  end

  # The sidebar and the signed-in focused layout: the mark beside the word.
  def medium
    render(LogoComponent.new(href: "#"))
  end

  # Signed-out pages: the mark alone, 48 px, above the heading.
  def large
    render(LogoComponent.new(href: "#", size: :large))
  end
end
