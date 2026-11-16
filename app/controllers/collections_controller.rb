# The signed-in person's own collections, shared between Personal study and Notes (docs/design/personal-study.md,
# Collection). Found through Current.user, so another person's is a 404. Each page lists only those it uses.
class CollectionsController < ApplicationController
  include HouseholdScoped

  before_action :set_collection, only: %i[ update destroy ]

  # A refused name comes back in the dialog, which stays open with the reason.
  def create
    authorize Collection
    @collection = Current.user.collections.add(collection_params)

    if @collection.persisted?
      redirect_to household_personal_studies_path(collection: @collection.id), notice: "Collection created."
    else
      render_form :new
    end
  end

  # Taking it out of Personal study while studies are in it is refused, in the dialog.
  def update
    if @collection.update(collection_params)
      redirect_to household_personal_studies_path(collection: @collection.id), notice: "Collection saved."
    else
      render_form :edit
    end
  end

  # The database keeps its studies, out of any collection (on_delete: :nullify).
  def destroy
    @collection.destroy!
    redirect_to household_personal_studies_path, notice: "Deleted #{@collection.name}. Its studies are kept."
  end

  private

  def set_collection
    @collection = Current.user.collections.find(params[:id])
    authorize @collection
  end

  def collection_params
    params.expect(collection: %i[ name used_in ])
  end

  # :new or :edit, whose form partial has the id new_collection or edit_collection_<id>.
  def render_form(action)
    render turbo_stream: turbo_stream.replace(helpers.dom_id(@collection, action), partial: "collections/#{action}_form", locals: { collection: @collection }),
           status: :unprocessable_content
  end
end
