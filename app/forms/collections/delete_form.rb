# The "Delete collection" button in its delete Dialog.
class Collections::DeleteForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Delete collection", scheme: :danger)
  end
end
