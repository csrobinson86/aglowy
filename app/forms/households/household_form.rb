class Households::HouseholdForm < ApplicationForm
  form do |f|
    f.text_field(name: :name, label: "Name", required: true)

    f.select_list(name: :time_zone, label: "Time zone") do |list|
      ActiveSupport::TimeZone.all.each { |zone| list.option(label: zone.to_s, value: zone.name) }
    end

    f.submit(name: :submit, label: "Create household", scheme: :primary)
  end
end
