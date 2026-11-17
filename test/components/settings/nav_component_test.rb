require "test_helper"

# The section nav (docs/design/settings.md, The section nav, On a phone).
class Settings::NavComponentTest < ViewComponent::TestCase
  setup { @home = households(:home) }

  test "a NavList labelled Settings with the You group's sections, linking to each page" do
    render_inline(Settings::NavComponent.new(household: @home, selected: :profile))

    assert_selector "nav[aria-label='Settings'] h2", text: "You"
    assert_equal [ "Profile", "Appearance", "Signing in", "My households" ], page.all("nav[aria-label='Settings'] a").map { it.text.strip }
    assert_equal %W[ /#{@home.id}/settings/profile /#{@home.id}/settings/appearance /#{@home.id}/settings/sign_in /#{@home.id}/settings/memberships ],
                 page.all("nav[aria-label='Settings'] a").map { it[:href] }
  end

  test "the current section is selected, and only it" do
    render_inline(Settings::NavComponent.new(household: @home, selected: :sign_in))

    assert_selector "nav[aria-label='Settings'] a[aria-current=page]", text: "Signing in"
    assert_selector "nav[aria-label='Settings'] a[aria-current=page]", count: 1
  end

  test "below md the nav is hidden and a menu button named after the current section takes its place" do
    render_inline(Settings::NavComponent.new(household: @home, selected: :appearance))

    assert_selector "nav[aria-label='Settings'].d-none.d-md-block"
    assert_selector ".settings-nav__menu.d-md-none button", text: "Appearance"
    assert_selector ".settings-nav__menu [role=menuitemradio][aria-checked=true]", text: "Appearance", visible: :all
    assert_selector ".settings-nav__menu [role=menuitemradio][aria-checked=true]", count: 1, visible: :all
    assert_selector ".settings-nav__menu a[href='/#{@home.id}/settings/memberships']", text: "My households", visible: :all
    assert_selector ".settings-nav__menu .ActionList-sectionDivider", text: "You", visible: :all
  end
end
