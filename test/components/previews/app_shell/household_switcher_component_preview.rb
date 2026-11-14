# The switcher for each state story #25 names: one household, several, a long name, a child.
class AppShell::HouseholdSwitcherComponentPreview < ViewComponent::Preview
  def one_household
    render_switcher([ "Rivera household", :head ])
  end

  def several_households
    render_switcher([ "Rivera household", :head ], [ "Grandma Ruth's household", :adult ])
  end

  def long_name
    render_switcher([ "The Extraordinarily Long-Named Rivera-Montgomery Household of Springfield", :head ],
      [ "Grandma Ruth's household", :adult ])
  end

  def child
    render_switcher([ "Rivera household", :child ], [ "Dad's household", :child ])
  end

  private
    # Unsaved records, so previews need no database rows; the first is the current household.
    def render_switcher(*households)
      user = User.new(name: "Maria Rivera")
      memberships = households.map do |name, role|
        Membership.new(role:, user:, household: Household.new(id: SecureRandom.uuid_v7, name:))
      end

      render(AppShell::HouseholdSwitcherComponent.new(membership: memberships.first, memberships:))
    end
end
