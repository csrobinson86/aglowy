# The "Delete study" button in a study's delete Dialog.
class PersonalStudies::DeleteForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Delete study", scheme: :danger)
  end
end
