# What the bookmark button posts besides itself: the page and where it's from when saving, and from: "list" on the
# Bookmarks tab, which then refreshes (BookmarkButtonComponent). Never a title: that comes from the source.
class Bookmarks::ButtonForm < ApplicationForm
  def initialize(fields:)
    @fields = fields
  end

  form do |f|
    @fields.each { |name, value| f.hidden(name:, value:, scope_name_to_model: false) }
  end
end
