# "Add a link" on the session page. The URL's host and path become the title (FamilyStudy::Resource).
class FamilyStudies::Sessions::Resources::LinkForm < ApplicationForm
  form do |f|
    f.group(layout: :horizontal) do |row|
      row.text_field(name: :url, label: "Add a link", type: :url, required: true, placeholder: "https://www.jw.org/…", full_width: true)
      row.submit(name: :submit, label: "Add link", align_self: :end)
    end
  end
end
