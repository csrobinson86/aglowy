# New go bag and Edit (docs/design/go-bags.md, Pages; frame go-bag-new.png). For lists Everyone, then the household's
# active members. Start with suggested items is on New only.
class GoBags::GoBagForm < ApplicationForm
  # members: who the bag can be for. suggested: whether Start with suggested items is ticked; nil leaves it out, as on
  # Edit. cancel_path: where Cancel goes.
  def initialize(members:, cancel_path:, suggested: nil)
    @members = members
    @cancel_path = cancel_path
    @suggested = suggested
  end

  form do |f|
    f.text_field(name: :name, label: "Name", required: true, maxlength: 80, full_width: true)
    f.text_field(name: :kept_at, label: "Where it's kept", caption: "So anyone can grab it in a hurry", maxlength: 80, full_width: true)
    # The error is on for_user, the association, so it's named here to show by its field.
    f.select_list(name: :for_user_id, label: "For", validation_message: go_bag.errors.full_messages_for(:for_user).first) do |list|
      list.option(label: "Everyone", value: "")
      @members.each { list.option(label: it.name, value: it.id) }
    end
    unless @suggested.nil?
      f.check_box(name: :suggested, label: "Start with suggested items", checked: @suggested,
                  caption: "About 35 common go-bag items, grouped and marked to buy. Remove what you don't need.")
    end
    f.group(layout: :horizontal) do |actions|
      actions.submit(name: :submit, label: go_bag.new_record? ? "Create bag" : "Save", scheme: :primary)
      actions.button(name: :cancel, label: "Cancel", tag: :a, href: @cancel_path, scheme: :link, align_self: :center)
    end
  end

  private
    def go_bag
      @builder.object
    end
end
