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
end
