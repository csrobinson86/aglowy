# The Save and Cancel buttons under the notes editor. The editor itself is the hand-built
# family_studies/sessions/notes/_field partial, since Primer forms have no rich-text input.
class FamilyStudies::Sessions::NotesForm < ApplicationForm
  def initialize(cancel_path:)
    @cancel_path = cancel_path
  end

  form do |f|
    f.group(layout: :horizontal) do |actions|
      actions.submit(name: :submit, label: "Save notes", scheme: :primary)
      actions.button(name: :cancel, label: "Cancel", tag: :a, href: @cancel_path, scheme: :link, align_self: :center)
    end
  end
end
