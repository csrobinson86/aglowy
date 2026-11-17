# The owner's tags on their bookmark, from its Edit dialog (docs/design/bookmarks.md, Pages and routes).
class Bookmarks::TaggingsController < ApplicationController
  include HouseholdScoped
  include TaggableScoped

  private

  # Through Current.user, so someone else's bookmark is a 404.
  def set_taggable
    @taggable = Current.user.bookmarks.find(params[:bookmark_id])
    authorize @taggable, :tag?
  end

  # The row's tags behind the dialog change with the editor, so a person who adds one and cancels still sees it, in
  # the row's labels and in its muted line on a phone.
  def render_tag_editor(status: :ok, **options)
    editor = TagEditorComponent.new(taggable: @taggable, user: Current.user, household: Current.household, **options)
    render turbo_stream: [
      turbo_stream.replace(editor.id, editor),
      turbo_stream.update(helpers.dom_id(@taggable, :tags), partial: "tags/labels", locals: { taggable: @taggable }),
      turbo_stream.update(helpers.dom_id(@taggable, :phone_tags), partial: "bookmarks/phone_tags", locals: { bookmark: @taggable })
    ], status:
  end
end
