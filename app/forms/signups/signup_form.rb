class Signups::SignupForm < ApplicationForm
  form do |f|
    f.text_field(name: :name, label: "Your name", required: true, autocomplete: "name")
    f.text_field(name: :email, label: "Email", type: :email, required: true, autocomplete: "email")
    # value: nil so a re-rendered form never sends the password back.
    f.text_field(name: :password, label: "Password", type: :password, value: nil, required: true,
                 autocomplete: "new-password", caption: "At least 6 characters")
    f.text_field(name: :household_name, label: "Household name", required: true, caption: "For example, The Robinson Family")

    f.select_list(name: :time_zone, label: "Time zone") do |list|
      ActiveSupport::TimeZone.all.each { |zone| list.option(label: zone.to_s, value: zone.name) }
    end

    f.submit(name: :submit, label: "Sign up", scheme: :primary)
  end
end
