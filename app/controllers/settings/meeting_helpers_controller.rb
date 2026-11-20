# Settings → Children: heads and adults turn the meeting helper for children on or off, and Get ready with it
# (docs/design/meeting-helper.md, Pages; docs/design/meeting-prep.md, The Settings check box).
class Settings::MeetingHelpersController < ApplicationController
  include HouseholdScoped

  def update
    authorize Current.household, :manage_meetings?

    redirect_to household_settings_children_path, notice: save_switches
  end

  private
    # Saves both boxes and returns the notice. Unticking the helper turns both off. Get ready's box shows only while
    # the helper is on, so a save from a page without it (the one that turns the helper on) leaves Get ready as it is.
    def save_switches
      household = Current.household
      return household.disable_meeting_helper.then { "Meeting helper turned off." } unless ticked?(:enabled)

      household.enable_meeting_helper(by: Current.user)
      if ticked?(:meeting_prep) && household.enable_meeting_prep(by: Current.user)
        "Meeting helper and Get ready cards turned on."
      elsif switches[:meeting_prep] == "0" && household.meeting_prep?
        household.disable_meeting_prep
        "Get ready cards turned off."
      else
        "Meeting helper turned on."
      end
    end

    # A check box sends "1", and its hidden field "0" when it's unticked.
    def ticked?(box)
      switches[box] == "1"
    end

    def switches
      @switches ||= params.expect(meeting_helper: [ :enabled, :meeting_prep ])
    end
end
