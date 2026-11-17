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

  test "My goals follows Notes in the Mine group, with the flag icon, and is the current item when selected_item is :personal_goals" do
    render_inline(AppShellComponent.new(membership: memberships(:head_in_home), selected_item: :personal_goals))

    assert_equal [ "Notes", "My goals" ], page.all("nav[aria-label='Main'] a").map { it.text.strip }.last(2)
    assert_selector "nav[aria-label='Main'] a[aria-current='page'][href='/#{households(:home).id}/my_goals']", text: "My goals"
    assert_selector "nav[aria-label='Main'] a[aria-current='page'] svg.octicon-flag"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", count: 1
  end

  test "Personal study sits between Today's meeting and Notes, with the search icon, and is the current item on its pages" do
    render_inline(AppShellComponent.new(membership: memberships(:child_in_home), selected_item: :personal_studies))

    assert_equal [ "Today's meeting", "Personal study", "Notes" ], page.all("nav[aria-label='Main'] a").map { it.text.strip }.last(4).first(3)
    assert_selector "nav[aria-label='Main'] a[aria-current='page'][href='/#{households(:home).id}/personal_studies']", text: "Personal study"
    assert_selector "nav[aria-label='Main'] a[aria-current='page'] svg.octicon-search"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", count: 1
  end

  test "Notes sits between Personal study and My goals, with the pencil icon, and is the current item on its pages" do
    render_inline(AppShellComponent.new(membership: memberships(:child_in_home), selected_item: :personal_notes))

    assert_equal [ "Personal study", "Notes", "My goals" ], page.all("nav[aria-label='Main'] a").map { it.text.strip }.last(3)
    assert_selector "nav[aria-label='Main'] a[aria-current='page'][href='/#{households(:home).id}/notes']", text: "Notes"
    assert_selector "nav[aria-label='Main'] a[aria-current='page'] svg.octicon-pencil"
    assert_selector "nav[aria-label='Main'] a[aria-current='page']", count: 1
  end

  test "shows the person's name and a Sign out button" do
    render_inline(AppShellComponent.new(membership: memberships(:head_in_home), selected_item: :dashboards))

    assert_text "Hannah Head"
    assert_selector "form[action='/identities/sign_out'] button", text: "Sign out"
  end

  test "no one sees Household settings: the household's sections are in Settings" do
    %i[ head_in_home spouse_in_home child_in_home ].each do |membership|
      render_inline(AppShellComponent.new(membership: memberships(membership), selected_item: :dashboards))

      assert_no_text "Household settings"
      assert_selector "nav[aria-label='Main settings'] a", text: "Settings", count: 1
    end
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
