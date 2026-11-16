# A note's title and collection, on the New note page and a note's page. The body's editor follows it, the hand-built
# meeting_notes/notes_field partial, since Primer forms have no rich-text input (CLAUDE.md, Forms). The collection
# select offers "None" and the person's collections for Notes.
class PersonalNotes::NoteForm < ApplicationForm
  def initialize(collections:)
    @collections = collections
  end

  form do |f|
    f.text_field(name: :title, label: "Title", required: true, full_width: true, maxlength: 120, size: :large)
    f.select_list(name: :collection_id, label: "Collection", include_blank: "None") do |list|
      @collections.each { |collection| list.option(label: collection.name, value: collection.id) }
    end
  end
end
