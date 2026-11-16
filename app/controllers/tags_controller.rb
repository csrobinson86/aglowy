# The signed-in person's own tags: My tags, a tag's page, rename and delete (docs/design/tags.md, Pages and routes).
# A tag is found by name through Current.user.tags, so another person's tag name, like an unknown one, is a 404.
# The pages sit under /:household_id only for the household layout; they look the same from any household.
class TagsController < ApplicationController
  include HouseholdScoped

  before_action :set_tag, except: :index

  def index
    authorize Tag
    @tags = Current.user.tags.with_taggings_count.order(:name)
  end

  def show
    @meeting_notes = @tag.meeting_notes
    @personal_studies = @tag.personal_studies
    @personal_notes = @tag.personal_notes
    @goals = @tag.goals.preloaded
  end

  # A taken name, or one that normalizes to nothing, comes back in the rename dialog, which stays open.
  def update
    if @tag.rename(params.expect(tag: [ :name ])[:name])
      redirect_to household_tags_path, notice: "Renamed to ##{@tag.name}."
    else
      render turbo_stream: turbo_stream.replace(helpers.dom_id(@tag, :rename), partial: "tags/rename_form", locals: { tag: @tag }), status: :unprocessable_content
    end
  end

  # The database deletes its taggings with it (on_delete: :cascade).
  def destroy
    @tag.destroy!
    redirect_to household_tags_path, notice: "Deleted ##{@tag.name}."
  end

  private

  def set_tag
    @tag = Current.user.tags.find_by!(name: params[:name])
    authorize @tag
  end
end
