# Delete bag, the answer to the dialog a bag's "…" opens (docs/design/go-bags.md, Edit / delete a bag).
class GoBags::DeleteForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Delete bag", scheme: :danger)
  end
end
