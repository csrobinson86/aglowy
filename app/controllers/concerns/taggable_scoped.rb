# Adding and removing the signed-in person's tags on one of their own things (docs/design/tags.md, Pages and routes).
# Each controller finds its parent through Current.user in set_taggable, so someone else's is a 404, and authorizes
# it. Both answer with a Turbo Stream that replaces the tag editor. (Not named Tagging: that's the model.)
module TaggableScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_taggable
  end

  # Body: name. A name that normalizes to nothing (a blank one too), or an 11th tag, shows its message in the editor.
  # Not params.require, which raises on a blank name instead of reaching the validation.
  def create
    @taggable.tag_with(params.fetch(:name, ""), by: Current.user)
    render_tag_editor focus: true
  rescue ActiveRecord::RecordInvalid => error
    render_tag_editor focus: true, error: error.record.errors.full_messages.to_sentence, status: :unprocessable_content
  end

  # The tag is looked up through Current.user.tags, never trusted from the URL (docs/design/tags.md, Traps).
  # The focused remove button goes with the tag, so focus moves to the input.
  def destroy
    @taggable.untag(Current.user.tags.find(params[:id]))
    render_tag_editor focus: true
  end

  private

  def render_tag_editor(status: :ok, **options)
    editor = TagEditorComponent.new(taggable: @taggable, user: Current.user, household: Current.household, **options)
    render turbo_stream: turbo_stream.replace(editor.id, editor), status: status
  end
end
