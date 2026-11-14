require "test_helper"

class AppShellComponentTest < ViewComponent::TestCase
  test "renders one main and a nav labelled Main" do
    render_inline(AppShellComponent.new(membership: memberships(:head_in_home), selected_item: :dashboards)) { "Page" }

    assert_selector "main", count: 1
    assert_selector "main", text: "Page"
    assert_selector "nav[aria-label='Main']", count: 1
  end

  test "Home has aria-current=page when selected_item is :dashboards" do
    render_inline(AppShellComponent.new(membership: memberships(:head_in_home), selected_item: :dashboards))

    assert_selector "nav[aria-label='Main'] a[aria-current='page']", text: "Home"
  end

  test "Home is not current on another section's page" do
    render_inline(AppShellComponent.new(membership: memberships(:head_in_home), selected_item: :members))

    assert_selector "nav[aria-label='Main'] a", text: "Home"
    assert_no_selector "a[aria-current='page']"
  end

  test "shows the person's name and a Sign out button" do
    render_inline(AppShellComponent.new(membership: memberships(:head_in_home), selected_item: :dashboards))

    assert_text "Hannah Head"
    assert_selector "form[action='/identities/sign_out'] button", text: "Sign out"
  end

  test "the previews render" do
    %i[ head child long_names ].each do |preview|
      render_preview(preview)

      assert_selector "nav[aria-label='Main']"
    end
  end
end
