# Delete category, the answer to the dialog a category's "…" opens on Settings → Go bags (docs/design/go-bags.md).
class Settings::GoBagCategoryDeletionForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Delete category", scheme: :danger)
  end
end
