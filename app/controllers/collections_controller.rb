# The signed-in person's own collections, shared between Personal study and Notes (docs/design/personal-study.md,
# Collection). Found through Current.user, so another person's is a 404. Each page lists only those it uses.
class CollectionsController < ApplicationController
  include HouseholdScoped

  before_action :set_collection, only: %i[ update destroy ]

  # A refused name comes back in the dialog, which stays open with the reason. One made on Notes goes back there.
  def create
    authorize Collection
    @collection = Current.user.collections.add(collection_params)

    if @collection.persisted?
      redirect_to notes? ? household_personal_notes_path(collection: @collection.id) : household_personal_studies_path(collection: @collection.id), notice: "Collection created."
    else
      render_form :new, section: notes? ? "notes" : "studies"
    end
  end

  # Taking it out of a section while things are in it there is refused, in the dialog. From Settings it goes back there.
  def update
    if @collection.revise(collection_params)
      redirect_to settings? ? household_settings_tags_path : household_personal_studies_path(collection: @collection.id), notice: "Collection saved."
    elsif settings?
      render_form :edit, partial: "settings/tags/collection_form"
    else
      render_form :edit
    end
  end

  # The database keeps its studies and notes, out of any collection (on_delete: :nullify).
  def destroy
    @collection.destroy!

    if settings?
      redirect_to household_settings_tags_path, notice: "Deleted #{@collection.name}. Everything in it is kept."
    else
      redirect_to household_personal_studies_path, notice: "Deleted #{@collection.name}. Its studies are kept."
    end
  end

  private

  def set_collection
    @collection = Current.user.collections.find(params[:id])
    authorize @collection
  end

  def collection_params
    params.expect(collection: %i[ name used_in ])
  end

  # Which section's New collection dialog it came from: section=notes from Notes, else Personal study.
  def notes?
    params[:section] == "notes"
  end

  # Whether its Edit or Delete dialog was on Settings → Tags and collections (section=settings).
  def settings?
    params[:section] == "settings"
  end

  # :new or :edit, whose form partial has the id new_collection or edit_collection_<id>.
  def render_form(action, partial: "collections/#{action}_form", **locals)
    render turbo_stream: turbo_stream.replace(helpers.dom_id(@collection, action), partial:, locals: { collection: @collection, **locals }),
           status: :unprocessable_content
  end
end
