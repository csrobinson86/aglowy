class Sessions::SignOutForm < ApplicationForm
  form do |f|
    f.submit(name: :sign_out, label: "Sign out", size: :small)
  end
end
