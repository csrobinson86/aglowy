# A person's own bookmarks: the Bookmarks tab of Notes, and saving and removing a page or a scripture with a study's or
# a note's bookmark button (docs/design/bookmarks.md, Pages and routes). They're the same in every household the person
# belongs to, so they're reached through Current.user, never Current.household or an id alone. So is the study or note
# one is saved from.
class BookmarksController < ApplicationController
  include HouseholdScoped

  PAGE_SIZE = 50
  KINDS = { "page" => :pages, "scripture" => :scriptures }.freeze

  # ?kind=page or ?kind=scripture narrows the list (Show); any other kind is ignored.
  def index
    authorize Bookmark
    @kind = params[:kind].presence_in(KINDS.keys)
    @page = Page.new(filtered(Current.user.bookmarks).preloaded.recent_first, number: params[:page], size: PAGE_SIZE)
    # Removing the last bookmark on a later page refreshes a page that's now empty: show the last one with bookmarks.
    return redirect_to household_bookmarks_path(kind: @kind, page: (@page.last_number if @page.last_number > 1)) if @page.past_the_end?

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
    @kind ? bookmarks.public_send(KINDS[@kind]) : bookmarks
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
