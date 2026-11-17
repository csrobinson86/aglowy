# Settings → Children, for heads and adults: the meeting helper's switch (Settings::MeetingHelpersController) and
# personal study with AI for each child, which only a head turns on or off (Memberships::StudyAiGrantsController;
# docs/design/personal-study.md, Children).
class Settings::ChildrenController < ApplicationController
  include HouseholdScoped

  def show
    authorize Current.household, :manage_meetings?
    @children = Current.household.memberships.active.child.preloaded.includes(study_ai_grant: :granted_by).by_role
  end
end
