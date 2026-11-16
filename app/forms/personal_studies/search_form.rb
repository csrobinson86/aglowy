# The search box above the list of studies. It keeps the collection and tag the list is narrowed to, and says
# what it searches: notes are encrypted, so it can't read them (docs/design/personal-study.md, Traps).
class PersonalStudies::SearchForm < ApplicationForm
  def initialize(query:, collection:, tag:)
    @query = query
    @collection = collection
    @tag = tag
  end

  form do |f|
    f.text_field(name: :q, label: "Search titles, collections and tags", visually_hide_label: true, type: :search, value: @query,
                 placeholder: "Search titles, collections and tags", full_width: true, leading_visual: { icon: :search })
    f.hidden(name: :collection, value: @collection) if @collection
    f.hidden(name: :tag, value: @tag) if @tag
  end
end
