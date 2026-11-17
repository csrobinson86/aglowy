# "Delete time" in the "my time" dialog's footer, behind a confirm.
class PersonalTimes::DeleteForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Delete time", scheme: :danger)
  end
end
