# The "Delete tag" button in My tags' delete Dialog.
class Tags::DeleteForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Delete tag", scheme: :danger)
  end
end
