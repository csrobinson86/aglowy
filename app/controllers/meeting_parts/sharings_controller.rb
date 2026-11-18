# Sharing a part with the household in the URL, and stopping. A person in two households shares into this one only
# (docs/design/meeting-parts.md, Sharing).
class MeetingParts::SharingsController < ApplicationController
  include HouseholdScoped

  before_action :set_meeting_part

  def create
    @meeting_part.share_with(Current.household)
    respond_with_sharing notice: "Shared with #{Current.household.name}."
  end

  def destroy
    @meeting_part.stop_sharing_with(Current.household)
    respond_with_sharing notice: "Stopped sharing with #{Current.household.name}."
  end

  private
    # From the page, the label and the button change in place, so the preparation and counsel keep what's typed and not
    # yet saved.
    def respond_with_sharing(notice:)
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = notice
          render :sharing
        end
        format.html { redirect_to household_meeting_part_path(id: @meeting_part), notice: notice }
      end
    end

    # Through Current.user, so someone else's part, shared here or not, is a 404.
    def set_meeting_part
      @meeting_part = Current.user.meeting_parts.find(params[:meeting_part_id])
      authorize @meeting_part, :share?
    end
end
