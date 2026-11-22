# The owner's tags on their personal goal (docs/design/tags.md, The tag editor).
class Goals::TaggingsController < ApplicationController
  include HouseholdScoped
  include TaggableScoped

  private

  # Through Current.user, so a family goal, or someone else's goal, is a 404.
  def set_taggable
    @taggable = Current.user.goals.find(params[:goal_id])
    authorize @taggable, :tag?
  end

  # The chips under the goal's why on a phone change with the editor in the Tags dialog, so closing it shows them.
  def render_tag_editor(status: :ok, **options)
    editor = TagEditorComponent.new(taggable: @taggable, user: Current.user, household: Current.household, **options)
    render turbo_stream: [
      turbo_stream.replace(editor.id, editor),
      turbo_stream.update(helpers.dom_id(@taggable, :tags), partial: "tags/labels", locals: { taggable: @taggable })
    ], status:
  end
end
