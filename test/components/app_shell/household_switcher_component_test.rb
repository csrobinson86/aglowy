require "test_helper"

class AppShell::HouseholdSwitcherComponentTest < ViewComponent::TestCase
  include Rails.application.routes.url_helpers

  test "lists only the person's active households" do
    memberships(:head_in_parents).update_column(:active, false)

    render_inline(AppShell::HouseholdSwitcherComponent.new(membership: memberships(:head_in_home)))

    assert_equal [ "The Head Family", "New household" ], page.all("action-menu .ActionListItem-label").map { it.text.strip }
    assert_no_text "The Grandparent Family"
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

  test "shows \"New household\" when the policy allows it" do
    assert HouseholdPolicy.new(memberships(:child_in_home), Household).create?

    render_inline(AppShell::HouseholdSwitcherComponent.new(membership: memberships(:child_in_home)))

    assert_selector "action-menu a[href='#{new_household_path}']", text: "New household"
  end

  test "the previews render" do
    %i[ one_household several_households long_name child ].each do |preview|
      render_preview(preview)

      assert_selector "action-menu"
      assert_selector "[role='menuitemradio'][aria-checked='true']", count: 1
    end
  end
end
