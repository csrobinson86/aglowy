# A person's own bookmarks: the Bookmarks tab of Notes, and saving and removing a page or a scripture with a study's or
# a note's bookmark button (docs/design/bookmarks.md, Pages and routes). They're the same in every household the person
# belongs to, so they're reached through Current.user, never Current.household or an id alone. So is the study or note
# one is saved from.
class BookmarksController < ApplicationController
  include HouseholdScoped
  include TagFiltered

  PAGE_SIZE = 50
  KINDS = { "page" => :pages, "scripture" => :scriptures }.freeze

  # ?kind=page or ?kind=scripture narrows the list (Show); any other kind is ignored. ?collection= and ?tag= narrow it
  # too: a collection that isn't one of the person's for Notes, like an unknown tag, narrows it to nothing. ?q= searches
  # titles, comments, collection names and tag names (Bookmark.matching).
  def index
    authorize Bookmark
    @kind = params[:kind].presence_in(KINDS.keys)
    @query = params[:q].to_s.squish.presence
    @collection_id = params[:collection].presence
    @collections = Current.user.collections.for_notes.with_bookmarks_count.positioned
    @collection = @collections.find { it.id == @collection_id } if @collection_id
    @tags = Current.user.tags.carried_by("Bookmark").order(:name)
    @filters = { kind: @kind, collection: @collection_id, tag: @tag_name, q: @query }.compact
    @total_count = Current.user.bookmarks.count
    @page = Page.new(tagged(filtered(Current.user.bookmarks)).preloaded.recent_first, number: params[:page], size: PAGE_SIZE)
    # Removing the last bookmark on a later page refreshes a page that's now empty: show the last one with bookmarks.
    return redirect_to household_bookmarks_path(**@filters, page: (@page.last_number if @page.last_number > 1)) if @page.past_the_end?

    @bookmarked = @page.records.to_h { [ it.key, it.id ] }
  end

  # A page's title comes from the study's own sources, never from the params; a page that isn't among them is refused,
  # and so is a scripture that isn't in the study's or note's scripture_references.
  def create
    authorize Current.user.bookmarks.new
    @source = source or raise ActiveRecord::RecordNotFound
    @bookmark = Current.user.bookmark(url: params[:url], scripture: params[:scripture].presence, source: @source)

    if @bookmark.persisted?
      respond_with_buttons
    else
      head :unprocessable_content
    end
  end

  # From the Edit dialog: a page's title, the comment and the collection. Saving replaces the row behind the dialog,
  # which closes it; a refused save shows its reasons by the fields, in the dialog.
  def update
    @bookmark = Current.user.bookmarks.find(params[:id])
    authorize @bookmark
    collections = Current.user.collections.for_notes.positioned

    if @bookmark.update(bookmark_attributes)
      render turbo_stream: turbo_stream.update(@bookmark, partial: "bookmarks/bookmark", locals: { bookmark: @bookmark, bookmarked: { @bookmark.key => @bookmark.id }, collections: })
    else
      render turbo_stream: turbo_stream.replace(helpers.dom_id(@bookmark, :edit), partial: "bookmarks/edit_form", locals: { bookmark: @bookmark, collections: }), status: :unprocessable_content
    end
  end

  # The button posts the study or note it's on, so the empty buttons that replace it save from there, wherever the
  # bookmark came from (or none, from the Bookmarks tab once its source is deleted).
  def destroy
    @bookmark = Current.user.bookmarks.find(params[:id])
    authorize @bookmark
    @source = source
    @bookmark.destroy!
    respond_with_buttons
  end

  private

  def filtered(bookmarks)
    bookmarks = bookmarks.public_send(KINDS[@kind]) if @kind
    bookmarks = @collection ? bookmarks.where(collection: @collection) : bookmarks.none if @collection_id
    @query ? bookmarks.matching(@query) : bookmarks
  end

  # Never the URL or the scripture, and a scripture has no title to rename. The collection is looked up through
  # Current.user.collections, so another person's is a 404; a blank one takes the bookmark out of any collection.
  def bookmark_attributes
    attributes = params.expect(bookmark: @bookmark.url ? %i[ title comment collection_id ] : %i[ comment collection_id ]).to_h
    if attributes.key?(:collection_id)
      collection_id = attributes.delete(:collection_id)
      attributes[:collection] = collection_id.presence && Current.user.collections.find(collection_id)
    end
    attributes
  end

  # The study or note the button is on, through Current.user, so another person's is never found.
  def source
    case params[:source_type]
    when "PersonalStudy" then Current.user.personal_studies.find_by(id: params[:source_id].to_s)
    when "PersonalNote" then Current.user.personal_notes.find_by(id: params[:source_id].to_s)
    end
  end

  # Every button for the page swaps at once, so Pages used and Sources in this study stay in step. The Bookmarks tab
  # knows its own page and count, so it refreshes itself. Without Turbo, back to where the person was.
  def respond_with_buttons
    respond_to do |format|
      format.turbo_stream do
        @refresh_list = params[:from] == "list"
        render :buttons
      end
      format.html { redirect_back_or_to household_bookmarks_path, status: :see_other }
    end
  end
end
