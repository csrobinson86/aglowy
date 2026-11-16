# The owner's tags on their note (docs/design/tags.md, The tag editor).
class PersonalNotes::TaggingsController < ApplicationController
  include HouseholdScoped
  include TaggableScoped

  private

  # Through Current.user, so someone else's note is a 404.
  def set_taggable
    @taggable = Current.user.personal_notes.find(params[:personal_note_id])
    authorize @taggable, :tag?
  end
end
