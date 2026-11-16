# A person's own notes. They're the same in every household the person belongs to, so they're reached through
# Current.user, never Current.household or an id alone (docs/design/notes.md, Pages and routes). A collection id from
# the form is looked up through Current.user.collections, so another person's is a 404.
class PersonalNotesController < ApplicationController
  include HouseholdScoped
  include TagFiltered

  before_action :set_personal_note, only: %i[ show update destroy ]

  # ?collection=, ?tag= and ?color= narrow the list, and ?q= searches titles, collection names and tag names. A
  # collection that isn't one of the person's for notes, like an unknown tag, filters the list to nothing; a color
  # that isn't on the filter is ignored.
  def index
    authorize PersonalNote
    @collections = Current.user.collections.for_notes.with_personal_notes_count.positioned
    @tags = Current.user.tags.with_taggings_count.order(:name)
    @query = params[:q].to_s.squish.presence
    @collection_id = params[:collection].presence
    @color = params[:color].presence_in(PersonalNote::FILTER_COLORS)
    @collection = @collections.find { it.id == @collection_id } if @collection_id
    @personal_notes = tagged(filtered(Current.user.personal_notes)).preloaded.recent_first
    @total_count = Current.user.personal_notes.count
  end

  def new
    @personal_note = Current.user.personal_notes.new(collection: Current.user.collections.for_notes.find_by(id: params[:collection]))
    authorize @personal_note
  end

  # References typed in the body are linked on save, as on every save.
  def create
    @personal_note = Current.user.personal_notes.new(note_attributes)
    authorize @personal_note
    @personal_note.link_scriptures

    if @personal_note.save
      redirect_to household_personal_note_path(id: @personal_note), notice: "Note saved."
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
  end

  # Title, color, collection and body. Anything refused shows the page again with the reason.
  def update
    @personal_note.assign_attributes(note_attributes)
    @personal_note.link_scriptures

    if @personal_note.save
      redirect_to household_personal_note_path(id: @personal_note), notice: "Note saved."
    else
      render :show, status: :unprocessable_content
    end
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

  # A blank collection_id takes the note out of any collection.
  def note_attributes
    attributes = params.expect(personal_note: %i[ title color collection_id body ]).to_h
    if attributes.key?(:collection_id)
      collection_id = attributes.delete(:collection_id)
      attributes[:collection] = collection_id.presence && Current.user.collections.find(collection_id)
    end
    attributes
  end
end
