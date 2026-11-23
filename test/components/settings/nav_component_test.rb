require "test_helper"

# The section nav (docs/design/settings.md, The section nav, On a phone).
class Settings::NavComponentTest < ViewComponent::TestCase
  setup { @home = households(:home) }

  test "a NavList labelled Settings with the You group's sections, linking to each page" do
    render_inline(Settings::NavComponent.new(membership: memberships(:child_in_home), selected: :profile))

    assert_selector "nav[aria-label='Settings'] h2", text: "You"
    assert_equal [ "Profile", "Appearance", "Signing in", "My households", "Tags and collections", "Calendar", "Notifications" ], page.all("nav[aria-label='Settings'] a").map { it.text.strip }
    assert_equal %W[ /#{@home.id}/settings/profile /#{@home.id}/settings/appearance /#{@home.id}/settings/sign_in /#{@home.id}/settings/memberships /#{@home.id}/settings/tags
                    /#{@home.id}/settings/calendar /#{@home.id}/settings/notifications ],
                 page.all("nav[aria-label='Settings'] a").map { it[:href] }
  end

  test "a head sees all five household sections, under the household's name" do
    render_inline(Settings::NavComponent.new(membership: memberships(:head_in_home), selected: :profile))

    assert_selector "nav[aria-label='Settings'] h2", text: "The Head Family"
    assert_equal [ "Household", "Meetings", "Children", "Go bags", "Members and roles" ], page.all("nav[aria-label='Settings'] a").map { it.text.strip }.last(5)
    assert_equal %W[ /#{@home.id}/settings/household /#{@home.id}/settings/meetings /#{@home.id}/settings/children /#{@home.id}/settings/go_bag_categories
                    /#{@home.id}/settings/members ],
                 page.all("nav[aria-label='Settings'] a").map { it[:href] }.last(5)
  end

  test "an adult sees Meetings, Children and Go bags only" do
    render_inline(Settings::NavComponent.new(membership: memberships(:spouse_in_home), selected: :meetings))

    assert_selector "nav[aria-label='Settings'] h2", text: "The Head Family"
    assert_equal [ "Profile", "Appearance", "Signing in", "My households", "Tags and collections", "Calendar", "Notifications", "Study guide", "Meetings", "Children",
                   "Go bags" ],
                 page.all("nav[aria-label='Settings'] a").map { it.text.strip }
    assert_selector ".settings-nav__menu a", text: "Children", visible: :all
    assert_selector ".settings-nav__menu a[href='/#{@home.id}/settings/go_bag_categories']", text: "Go bags", visible: :all
    assert_no_selector ".settings-nav__menu a", text: "Members and roles", visible: :all
  end

  # For a head or adult in any household (docs/design/study-guide.md, The Settings section).
  test "a head sees Study guide last in the You group; a child doesn't" do
    render_inline(Settings::NavComponent.new(membership: memberships(:head_in_home), selected: :study_guide))

    assert_equal [ "Calendar", "Notifications", "Study guide", "Household" ], page.all("nav[aria-label='Settings'] a").map { it.text.strip }[5..8]
    assert_selector "nav[aria-label='Settings'] a[href='/#{@home.id}/settings/study_guide'][aria-current=page]", text: "Study guide"

    render_inline(Settings::NavComponent.new(membership: memberships(:child_in_home), selected: :profile))

    assert_no_selector "a[href$='/settings/study_guide']", visible: :all
  end

  test "a child sees no household group" do
    render_inline(Settings::NavComponent.new(membership: memberships(:child_in_home), selected: :profile))

    assert_no_text "The Head Family"
    assert_selector "nav[aria-label='Settings'] h2", count: 1
    assert_no_selector "a[href$='/settings/meetings']", visible: :all
    assert_no_selector "a[href$='/settings/go_bag_categories']", visible: :all
  end

  test "the current section is selected, and only it" do
    render_inline(Settings::NavComponent.new(membership: memberships(:head_in_home), selected: :members))

    assert_selector "nav[aria-label='Settings'] a[aria-current=page]", text: "Members and roles"
    assert_selector "nav[aria-label='Settings'] a[aria-current=page]", count: 1
  end

  test "below md the nav is hidden and a menu button named after the current section takes its place" do
    render_inline(Settings::NavComponent.new(membership: memberships(:head_in_home), selected: :appearance))

    assert_selector "nav[aria-label='Settings'].d-none.d-md-block"
    assert_selector ".settings-nav__menu.d-md-none button", text: "Appearance"
    assert_selector ".settings-nav__menu [role=menuitemradio][aria-checked=true]", text: "Appearance", visible: :all
    assert_selector ".settings-nav__menu [role=menuitemradio][aria-checked=true]", count: 1, visible: :all
    assert_selector ".settings-nav__menu a[href='/#{@home.id}/settings/memberships']", text: "My households", visible: :all
    assert_selector ".settings-nav__menu .ActionList-sectionDivider", text: "You", visible: :all
    assert_selector ".settings-nav__menu .ActionList-sectionDivider", text: "The Head Family", visible: :all
    assert_selector ".settings-nav__menu a[href='/#{@home.id}/settings/members']", text: "Members and roles", visible: :all
  end
end
