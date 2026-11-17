# The search box on the Bookmarks tab (docs/design/bookmarks.md, The Bookmarks tab). It keeps the kind, collection and
# tag the list is narrowed to. Titles and comments are encrypted, so Bookmark.matching reads them in Ruby.
class Bookmarks::SearchForm < ApplicationForm
  def initialize(query:, filters:)
    @query = query
    @filters = filters.except(:q)
  end

  form do |f|
    f.text_field(name: :q, label: "Search titles, comments, collections and tags", visually_hide_label: true, type: :search, value: @query,
                 placeholder: "Search titles, comments, collections and tags", full_width: true, leading_visual: { icon: :search })
    @filters.each { |name, value| f.hidden(name:, value:) }
  end
end
