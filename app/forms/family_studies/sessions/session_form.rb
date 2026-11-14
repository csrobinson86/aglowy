# Edit a session: Topic, Date and Starts for this session only (docs/design/family-studies.md, Pages).
class FamilyStudies::Sessions::SessionForm < ApplicationForm
  def initialize(cancel_path:)
    @cancel_path = cancel_path
  end

  form do |f|
    f.text_field(name: :topic, label: "Topic", placeholder: "For example, Proverbs 3 or preparing for the memorial", full_width: true)
    f.group(layout: :horizontal) do |row|
      row.text_field(name: :starts_on, label: "Date", type: :date, required: true, caption: "Changes this session only.")
      row.text_field(name: :starts_at, label: "Starts", type: :time, required: true, value: f.builder.object.starts_at&.strftime("%H:%M"))
    end
    f.group(layout: :horizontal) do |actions|
      actions.submit(name: :submit, label: "Save session", scheme: :primary)
      actions.button(name: :cancel, label: "Cancel", tag: :a, href: @cancel_path, scheme: :link, align_self: :center)
    end
  end
end
