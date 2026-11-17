# Settings → Children: heads and adults turn the meeting helper for children on or off (docs/design/meeting-helper.md, Pages).
class Settings::MeetingHelpersController < ApplicationController
  include HouseholdScoped

  def update
    authorize Current.household, :manage_meetings?

    if enabled?
      Current.household.enable_meeting_helper(by: Current.user)
      redirect_to household_settings_children_path, notice: "Meeting helper turned on."
    else
      Current.household.disable_meeting_helper
      redirect_to household_settings_children_path, notice: "Meeting helper turned off."
    end
  end

  private
    # The check box sends "1", and its hidden field "0" when it's unticked.
    def enabled?
      params.expect(meeting_helper: [ :enabled ])[:enabled] == "1"
    end
end
