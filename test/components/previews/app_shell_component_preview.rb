# The shell for each state UI-01 names (docs/design/app-shell.md, States every UI story checks).
class AppShellComponentPreview < ViewComponent::Preview
  def head
    render_shell(role: :head, household_name: "Rivera household", person_name: "Maria Rivera")
  end

  def child
    render_shell(role: :child, household_name: "Rivera household", person_name: "Sofia Rivera")
  end

  def long_names
    render_shell(role: :head,
      household_name: "The Extraordinarily Long-Named Rivera-Montgomery Household of Springfield",
      person_name: "Maria Alejandra Guadalupe Rivera-Montgomery")
  end

  private
    # Unsaved records, so previews need no database rows; the id gives the household a URL.
    def render_shell(role:, household_name:, person_name:)
      membership = Membership.new(role:,
        household: Household.new(id: SecureRandom.uuid_v7, name: household_name),
        user: User.new(name: person_name))

      render(AppShellComponent.new(membership:, selected_item: :dashboards)) { "Page content" }
    end
end
