# "Delete focus area" in the focus area's delete Dialog.
class DailyBriefs::Plans::FocusAreaDeleteForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Delete focus area", scheme: :danger)
  end
end
