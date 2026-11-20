# A person's own notes. They're the same in every household the person belongs to, so they're reached through
# Current.user, never Current.household or an id alone (docs/design/notes.md, Pages and routes). A collection id from
# the form is looked up through Current.user.collections, so another person's is a 404.
class PersonalNotesController < ApplicationController
  include HouseholdScoped
  include TagFiltered

  before_action :set_personal_note, only: %i[ show edit update destroy ]

  # ?collection=, ?tag= and ?color= narrow the list, and ?q= searches titles, collection names and tag names. A
  # collection that isn't one of the person's for notes, like an unknown tag, filters the list to nothing; a color
  # that isn't on the filter is ignored. Pinned notes come first, under Pinned, and the filters narrow them too.
  def index
    authorize PersonalNote
    @collections = Current.user.collections.for_notes.with_personal_notes_count.positioned
    @tags = Current.user.tags.with_taggings_count.order(:name)
    @query = params[:q].to_s.squish.presence
    @collection_id = params[:collection].presence
    @color = params[:color].presence_in(PersonalNote::FILTER_COLORS)
    @collection = @collections.find { it.id == @collection_id } if @collection_id
    notes = tagged(filtered(Current.user.personal_notes)).preloaded
    @pinned_notes = notes.pinned.load
    @personal_notes = notes.unpinned.recent_first.load
    @total_count = Current.user.personal_notes.count
  end

  # ?title= fills the title, as the daily brief's "Write a note about today" does with the date. Nothing is saved until
  # the person saves the note.
  def new
    @personal_note = Current.user.personal_notes.new(title: params[:title], collection: Current.user.collections.for_notes.find_by(id: params[:collection]))
    authorize @personal_note
  end

  # References typed in the body are linked on save, as on every save.
  def create
    @personal_note = Current.user.personal_notes.new(note_attributes.except(:tag_names))
    authorize @personal_note
    @personal_note.link_scriptures

    if @personal_note.save
      redirect_to household_personal_note_path(id: @personal_note), notice: "Note saved."
    else
      render :new, status: :unprocessable_content
    end
  end

  # The read view (docs/design/notes.md, A note).
  def show
  end

  def edit
  end

  # Title, color, collection and body, saved only when the form's base is the note as it is now (the version check).
  # Anything refused shows the form again with the reason. A stale save shows the note as it is now, with what the form
  # sent under "What you wrote".
  def update
    base = params.dig(:personal_note, :base)
    attributes = note_attributes(stale: -> { !@personal_note.reload.based_on?(base) })

    if @personal_note.revise(attributes, base:)
      redirect_to household_personal_note_path(id: @personal_note), notice: "Note saved."
    else
      render :edit, status: :unprocessable_content
    end
  rescue ActiveRecord::StaleObjectError
    @written = PersonalNote.new(attributes.except(:tag_names))
    @written_tag_names = attributes[:tag_names].to_s.split
    render :edit, status: :conflict
  end

  def destroy
    @personal_note.destroy!
    redirect_to household_personal_notes_path, notice: "Note deleted."
  end

  private

  def set_personal_note
    @personal_note = Current.user.personal_notes.preloaded.find(params[:id])
    authorize @personal_note
  end

  def filtered(notes)
    notes = @collection ? notes.where(collection: @collection) : notes.none if @collection_id
    notes = notes.colored(@color) if @color
    @query ? notes.matching(@query) : notes
  end

  # A blank collection_id takes the note out of any collection. tag_names, the names the tag editor showed, are only
  # for "What you wrote". A collection that isn't found is a 404, unless the save will be refused as stale (deleted in
  # another window since the form was rendered): then it's left out, so "What you wrote" still shows the rest. stale
  # is asked only then, after the lookup, so it reads the note as it is now: updated_at only moves forward, so a note
  # changed before the lookup stays stale under revise's lock.
  def note_attributes(stale: -> { false })
    attributes = params.expect(personal_note: %i[ title color collection_id body tag_names ]).to_h
    if attributes.key?(:collection_id)
      collection_id = attributes.delete(:collection_id).presence
      collections = Current.user.collections
      attributes[:collection] = collection_id && (collections.find_by(id: collection_id) || (collections.find(collection_id) unless stale.call))
    end
    attributes
  end
end
