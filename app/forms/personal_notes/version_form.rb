# The edit form's hidden fields for the version check (docs/design/notes.md, A note: the version check): base, the
# note's version when the form was rendered, and tag_names, the tags the editor shows. The note-tag-names controller
# refreshes tag_names as the form is sent, since tags are added beside the form; they're only for "What you wrote".
class PersonalNotes::VersionForm < ApplicationForm
  def initialize(tag_names:)
    @tag_names = tag_names
  end

  form do |f|
    f.hidden(name: :base)
    f.hidden(name: :tag_names, value: @tag_names.join(" "), data: { note_tag_names_target: "field" })
  end
end
