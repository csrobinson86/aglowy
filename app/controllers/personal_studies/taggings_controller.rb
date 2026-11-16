# The owner's tags on their personal study (docs/design/tags.md, The tag editor).
class PersonalStudies::TaggingsController < ApplicationController
  include HouseholdScoped
  include TaggableScoped

  private

  # Through Current.user, so someone else's study is a 404.
  def set_taggable
    @taggable = Current.user.personal_studies.find(params[:personal_study_id])
    authorize @taggable, :tag?
  end
end
