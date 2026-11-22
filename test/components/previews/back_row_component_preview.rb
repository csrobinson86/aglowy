# An inner page's back row on a phone (docs/design/phone.md, The rules: 2). Shown below md only, so narrow the preview.
class BackRowComponentPreview < ViewComponent::Preview
  # A page with its own actions: the "…" at the right end, as a goal's for someone who can edit it.
  def with_menu
    render(BackRowComponent.new(href: "#", label: "My goals")) do |row|
      row.with_menu do
        row.render(Primer::Alpha::ActionMenu.new(menu_id: "preview-menu", anchor_align: :end)) do |menu|
          menu.with_show_button(icon: :"kebab-horizontal", scheme: :invisible, "aria-label": "Goal actions", show_tooltip: false)
          menu.with_item(label: "Edit goal", href: "#")
        end
      end
    end
  end

  # A page with no actions for this person, as a child's view of a family goal.
  def without_menu
    render(BackRowComponent.new(href: "#", label: "Family goals"))
  end
end
