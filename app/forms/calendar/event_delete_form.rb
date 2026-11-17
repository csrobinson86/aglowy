# "Delete event" in the household event dialog's footer, behind a confirm.
class Calendar::EventDeleteForm < ApplicationForm
  form do |f|
    f.submit(name: :submit, label: "Delete event", scheme: :danger)
  end
end
