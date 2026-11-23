# An item's dialog or page (docs/design/go-bags.md, An item; frame go-bag-item.png). Category lists No category, then
# the household's categories. "We have it" isn't a column: GoBag::Item#save_with saves it as the acquisition. On an
# existing item Remove item sits beside Save and submits the delete form after this one (go_bags/items/_form).
class GoBags::ItemForm < ApplicationForm
  DELETE_FORM_ID = "go-bag-item-delete"

  # categories: the household's, in order. have: whether "We have it" is ticked.
  def initialize(categories:, have:)
    @categories = categories
    @have = have
  end

  form do |f|
    f.text_field(name: :name, label: "Name", required: true, maxlength: 100, full_width: true)
    # The error is on category, the association, so it's named here to show by its field.
    f.select_list(name: :category_id, label: "Category", full_width: true, validation_message: item.errors.full_messages_for(:category).first) do |list|
      list.option(label: "No category", value: "")
      @categories.each { list.option(label: it.name, value: it.id) }
    end
    f.group(layout: :horizontal) do |pair|
      pair.text_field(name: :quantity, label: "How many", maxlength: 40)
      pair.text_field(name: :use_by, label: "Use by (optional)", type: :date)
    end
    f.text_field(name: :stored_at, label: "Stored somewhere else?", caption: "Leave empty when it's in the bag",
                 placeholder: "For example, the kitchen drawer", maxlength: 80, full_width: true)
    f.check_box(name: :have, label: "We have it", checked: @have)
    f.group(layout: :horizontal) do |actions|
      actions.submit(name: :submit, label: item.new_record? ? "Add item" : "Save", scheme: :primary)
      # It submits the delete form, named by the "form" attribute, a string because the DSL takes form: for itself.
      actions.submit(name: :remove, label: "Remove item", scheme: :danger, "form" => DELETE_FORM_ID) if item.persisted?
    end
  end

  private
    def item
      @builder.object
    end
end
