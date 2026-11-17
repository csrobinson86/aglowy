# frozen_string_literal: true

# The bookmark button beside a page (docs/design/bookmarks.md, The bookmark button): an empty bookmark that saves the
# page from its source, or a filled one that removes it, with aria-pressed. bookmarked is User#bookmarked, read once
# for the whole page, so the buttons cost no query each. Every button for one page carries the same key, a digest of
# the URL, so a save or remove can replace them all at once; never the raw URL.
class BookmarkButtonComponent < ApplicationComponent
  attr_reader :url, :title, :source, :household

  def self.key(url) = Digest::SHA256.hexdigest(url)

  # from_list: on the Bookmarks tab, where removing refreshes the tab.
  def initialize(url:, title:, source:, bookmarked:, household: Current.household, from_list: false)
    @url = Bookmark.normalize_value_for(:url, url)
    @title = title
    @source = source
    @bookmark_id = bookmarked[@url]
    @household = household
    @from_list = from_list
  end

  # A link that isn't a jw.org or wol.jw.org page can't be bookmarked, and nor can a page with nowhere it came from:
  # its title comes from the source. Removing needs neither.
  def render? = url.present? && (saved? || source.present?)

  def key = self.class.key(url)

  def saved? = @bookmark_id.present?

  def label
    name = title.presence || helpers.source_host(url)
    saved? ? "Remove bookmark: #{name}" : "Bookmark: #{name}"
  end

  def form_url
    saved? ? household_bookmark_path(household_id: household, id: @bookmark_id) : household_bookmarks_path(household_id: household)
  end

  # Saving posts the page and its source; removing posts the source too, so the empty buttons that replace this one
  # save from the page the person is on. Never a title: that comes from the source.
  def fields
    fields = source ? { source_type: source.class.name, source_id: source.id } : {}
    fields[:from] = "list" if @from_list
    saved? ? fields : fields.merge(url:)
  end
end
