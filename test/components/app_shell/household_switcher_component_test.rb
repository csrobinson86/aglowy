require "test_helper"

class AppShell::HouseholdSwitcherComponentTest < ViewComponent::TestCase
  include Rails.application.routes.url_helpers

  test "two households list only the households, with no \"New household\" and no divider" do
    render_inline(AppShell::HouseholdSwitcherComponent.new(membership: memberships(:head_in_home)))

    assert_equal [ "The Grandparent Family", "The Head Family" ], page.all("action-menu .ActionListItem-label").map { it.text.strip }
    assert_no_text "New household"
    assert_no_selector "action-menu a[href='#{new_household_path}']"
    assert_no_selector "action-menu .ActionList-sectionDivider"
  end

  test "lists only the person's active households" do
    Membership.create!(user: users(:head), household: households(:other), role: :adult, active: false)

    render_inline(AppShell::HouseholdSwitcherComponent.new(membership: memberships(:head_in_home)))

    assert_equal [ "The Grandparent Family", "The Head Family" ], page.all("action-menu .ActionListItem-label").map { it.text.strip }
    assert_no_text "The Outsider Family"
  end

  test "the current one is checked" do
    render_inline(AppShell::HouseholdSwitcherComponent.new(membership: memberships(:head_in_home)))

    assert_selector "a[aria-checked='true'][href='#{household_root_path(household_id: households(:home))}']", text: "The Head Family"
    assert_selector "a[aria-checked='false'][href='#{household_root_path(household_id: households(:parents))}']", text: "The Grandparent Family"
  end

  test "each shows the person's role in it" do
    render_inline(AppShell::HouseholdSwitcherComponent.new(membership: memberships(:head_in_home)))

    assert_selector "[role='menuitemradio']", text: /The Head Family\s*Head/
    assert_selector "[role='menuitemradio']", text: /The Grandparent Family\s*Adult/
    assert_selector "button", text: /The Head Family\s*Head/
  end

  test "one household renders its name and role as text with no action-menu and no button" do
    render_inline(AppShell::HouseholdSwitcherComponent.new(membership: memberships(:spouse_in_home)))

    assert_selector ".Truncate-text.text-bold", text: "The Head Family"
    assert_selector ".f6.color-fg-muted", text: "Adult"
    assert_no_selector "action-menu"
    assert_no_selector "button"
    assert_no_selector "a"
    assert_no_selector "svg.octicon-chevron-down"
    assert_no_text "New household"
  end

  test "a long name truncates, with one household and with several" do
    %i[ long_name long_name_one_household ].each do |preview|
      render_preview(preview)

      assert_selector ".min-width-0 .Truncate .Truncate-text", text: "The Extraordinarily Long-Named Rivera-Montgomery Household of Springfield"
    end
  end

  test "the previews for one household render as text" do
    %i[ one_household long_name_one_household ].each do |preview|
      render_preview(preview)

      assert_text(/Rivera.*Head/m)
      assert_no_selector "action-menu"
      assert_no_selector "button"
    end
  end

  test "the previews for two households render a menu" do
    %i[ several_households long_name child ].each do |preview|
      render_preview(preview)

      assert_selector "action-menu"
      assert_selector "[role='menuitemradio']", count: 2
      assert_selector "[role='menuitemradio'][aria-checked='true']", count: 1
      assert_no_text "New household"
    end
  end
end
