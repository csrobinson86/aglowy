require "test_helper"

# Every Settings page's frame (docs/design/settings.md, The page).
class Settings::PageComponentTest < ViewComponent::TestCase
  test "the h1, the section nav, then the section's title, its note and its body" do
    render_inline(Settings::PageComponent.new(membership: memberships(:head_in_home), section: :memberships)) do |page|
      page.with_body { "The boxes" }
    end

    assert_selector "h1", text: "Settings"
    assert_selector "nav[aria-label='Settings'] a[aria-current=page]", text: "My households"
    assert_selector "h2.settings-page__title", text: "My households"
    assert_selector "p", text: "The households you belong to."
    assert_text "The boxes"
  end

  test "a household section's note names the household" do
    render_inline(Settings::PageComponent.new(membership: memberships(:spouse_in_home), section: :meetings)) { |page| page.with_body { "" } }

    assert_selector "h2.settings-page__title", text: "Meetings"
    assert_selector "p", text: "The Head Family · heads and adults can change this."
  end
end
