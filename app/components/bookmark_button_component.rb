# frozen_string_literal: true

# The bookmark button beside a page or a scripture (docs/design/bookmarks.md, The bookmark button): an empty bookmark
# that saves it from its source, or a filled one that removes it, with aria-pressed. bookmarked is User#bookmarked,
# read once for the whole page, so the buttons cost no query each. Every button for one page or scripture carries the
# same key, a digest of the URL or the scripture's id, so a save or remove can replace them all at once; never the
# raw URL.
class BookmarkButtonComponent < ApplicationComponent
  attr_reader :url, :title, :scripture, :source, :household

  def self.key(url_or_scripture) = Digest::SHA256.hexdigest(url_or_scripture)

  # scripture: a Bible::Reference. from_list: on the Bookmarks tab, where removing refreshes the tab.
  def initialize(source:, bookmarked:, url: nil, title: nil, scripture: nil, household: Current.household, from_list: false)
    @url = Bookmark.normalize_value_for(:url, url) if url
    @title = title
    @scripture = scripture
    @source = source
    @bookmark_id = bookmarked[bookmarked_key]
    @household = household
    @from_list = from_list
  end

  # A link that isn't a jw.org or wol.jw.org page can't be bookmarked, and nor can anything with nowhere it came from:
  # a page's title comes from the source, and a scripture must be in it. Removing needs neither.
  def render? = bookmarked_key.present? && (saved? || source.present?)

  def key = self.class.key(bookmarked_key)

  def saved? = @bookmark_id.present?

  def label
    name = scripture ? scripture.to_s : title.presence || helpers.source_host(url)
    saved? ? "Remove bookmark: #{name}" : "Bookmark: #{name}"
  end

  def form_url
    saved? ? household_bookmark_path(household_id: household, id: @bookmark_id) : household_bookmarks_path(household_id: household)
  end

  # Saving posts the page or scripture and its source; removing posts the source too, so the empty buttons that
  # replace this one save from the page the person is on. Never a title: that comes from the source.
  def fields
    fields = source ? { source_type: source.class.name, source_id: source.id } : {}
    fields[:from] = "list" if @from_list
    return fields if saved?

    scripture ? fields.merge(scripture: scripture.id) : fields.merge(url:)
  end

  private
    # What User#bookmarked holds it by: the normalized URL, or the scripture's id (Bookmark#key).
    def bookmarked_key
      url || scripture&.id
    end
end
