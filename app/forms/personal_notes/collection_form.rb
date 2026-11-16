# A note's collection, under its color: "None" and the person's collections for Notes.
class PersonalNotes::CollectionForm < ApplicationForm
  def initialize(collections:)
    @collections = collections
  end

  form do |f|
    f.select_list(name: :collection_id, label: "Collection", include_blank: "None") do |list|
      @collections.each { |collection| list.option(label: collection.name, value: collection.id) }
    end
  end
end
