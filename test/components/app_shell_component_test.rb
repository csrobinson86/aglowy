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

  test "Family studies follows Home, with the book icon, and is the current item when selected_item is :family_studies" do
    render_inline(AppShellComponent.new(membership: memberships(:head_in_home), selected_item: :family_studies))

    assert_selector "nav[aria-label='Main'] li:nth-of-type(1) a", text: "Home"
    assert_selector "nav[aria-label='Main'] li:nth-of-type(2) a[aria-current='page'][href='/#{households(:home).id}/family_studies']", text: "Family studies"
    assert_selector "nav[aria-label='Main'] li:nth-of-type(2) svg.octicon-book"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", count: 1
  end

  test "Members follows Family studies and is the current item when selected_item is :members" do
    render_inline(AppShellComponent.new(membership: memberships(:head_in_home), selected_item: :members))

    assert_selector "nav[aria-label='Main'] li:nth-of-type(1) a", text: "Home"
    assert_selector "nav[aria-label='Main'] li:nth-of-type(3) a[aria-current='page']", text: "Members"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", count: 1
    assert_selector "nav[aria-label='Menu'] a[aria-current='page']", text: "Members", count: 1
  end

  test "Family goals follows Members, with the goal icon, and is the current item when selected_item is :goals" do
    render_inline(AppShellComponent.new(membership: memberships(:head_in_home), selected_item: :goals))

    assert_selector "nav[aria-label='Main'] li:nth-of-type(4) a[aria-current='page'][href='/#{households(:home).id}/goals']", text: "Family goals"
    assert_selector "nav[aria-label='Main'] li:nth-of-type(4) svg.octicon-goal"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", count: 1
  end

  test "Meeting notes is in the Mine group, with the note icon, and is the current item when selected_item is :meeting_notes" do
    render_inline(AppShellComponent.new(membership: memberships(:head_in_home), selected_item: :meeting_notes))

    assert_selector "nav[aria-label='Main'] h2", text: "Mine"
    assert_selector "nav[aria-label='Main'] a[aria-current='page'][href='/#{households(:home).id}/meeting_notes']", text: "Meeting notes"
    assert_selector "nav[aria-label='Main'] a[aria-current='page'] svg.octicon-note"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", count: 1
  end

  test "shows the person's name, linking to their account settings, and a Sign out button" do
    render_inline(AppShellComponent.new(membership: memberships(:head_in_home), selected_item: :dashboards))

    assert_selector "a[href='/account?return_to=#{households(:home).id}']", text: "Hannah Head"
    assert_selector "form[action='/identities/sign_out'] button", text: "Sign out"
  end

  test "the sidebar is hidden below md, where the phone menu takes over" do
    render_inline(AppShellComponent.new(membership: memberships(:head_in_home), selected_item: :dashboards))

    assert_selector ".Layout.Layout--sidebarPosition-flowRow-none"
  end

  test "the phone menu dialog holds the sidebar navigation labelled Menu" do
    render_inline(AppShellComponent.new(membership: memberships(:head_in_home), selected_item: :dashboards))

    assert_selector "header button[data-show-dialog-id='#{AppShellComponent::MENU_ID}'] + tool-tip[data-type='label']", text: "Open menu", visible: :all
    assert_selector "dialog##{AppShellComponent::MENU_ID}", visible: :all
    assert_selector "dialog nav[aria-label='Menu'] a[aria-current='page']", text: "Home", visible: :all
    assert_selector "dialog nav[aria-label='Menu'] a", text: "Members", visible: :all
  end

  test "each household switcher has its own menu id" do
    render_inline(AppShellComponent.new(membership: memberships(:head_in_home), selected_item: :dashboards))

    ids = page.all("action-menu button[aria-haspopup='true']", visible: :all).map { it[:id] }
    assert_equal 3, ids.size
    assert_equal ids.uniq, ids
  end

  test "the previews render" do
    %i[ head child long_names ].each do |preview|
      render_preview(preview)

      assert_selector "nav[aria-label='Main']"
    end
  end
end
