# The switcher's states (docs/design/app-shell.md, Anatomy of the shell): one household, shown as text; several, as a
# menu; a long name with each; a child's menu.
class AppShell::HouseholdSwitcherComponentPreview < ViewComponent::Preview
  LONG_NAME = "The Extraordinarily Long-Named Rivera-Montgomery Household of Springfield"

  def one_household
    render_switcher([ "Rivera household", :head ])
  end

  def several_households
    render_switcher([ "Rivera household", :head ], [ "Grandma Ruth's household", :adult ])
  end

  def long_name
    render_switcher([ LONG_NAME, :head ], [ "Grandma Ruth's household", :adult ])
  end

  def long_name_one_household
    render_switcher([ LONG_NAME, :head ])
  end

  def child
    render_switcher([ "Rivera household", :child ], [ "Dad's household", :child ])
  end

  private
    # Unsaved records, so previews need no database rows; the first is the current household.
    def render_switcher(*households)
      user = User.new(name: "Maria Rivera")
      memberships = households.map do |name, role|
        user.memberships.build(role:, household: Household.new(id: SecureRandom.uuid_v7, name:))
      end

      render(AppShell::HouseholdSwitcherComponent.new(membership: memberships.first, memberships:))
    end
end
