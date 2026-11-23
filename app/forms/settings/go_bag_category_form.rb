# Add category and Rename on Settings → Go bags, in the row's Turbo Frame (docs/design/go-bags.md, Settings → Go bags).
# The 50 limit's error is on base, so it's named here to show by the field.
class Settings::GoBagCategoryForm < ApplicationForm
  # cancel_path: where Cancel goes, the section, which puts the row back in its frame.
  def initialize(cancel_path:)
    @cancel_path = cancel_path
  end

  form do |f|
    f.text_field(name: :name, label: "Name", required: true, maxlength: 40, full_width: true, autofocus: true,
                 validation_message: category.errors[:base].first)
    f.group(layout: :horizontal) do |actions|
      actions.submit(name: :submit, label: category.new_record? ? "Add category" : "Save", scheme: :primary)
      actions.button(name: :cancel, label: "Cancel", tag: :a, href: @cancel_path, scheme: :link, align_self: :center)
    end
  end

  private
    def category
      @builder.object
    end
end
