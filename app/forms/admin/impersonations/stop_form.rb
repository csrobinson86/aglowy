class Admin::Impersonations::StopForm < ApplicationForm
  form do |f|
    f.submit(name: :stop_impersonating, label: "Stop impersonating", size: :small)
  end
end
