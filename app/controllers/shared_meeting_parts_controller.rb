# The parts members have shared into this household, for every active member to read, coming up then earlier
# (docs/design/meeting-parts.md, The list). Each row names its owner.
class SharedMeetingPartsController < ApplicationController
  include HouseholdScoped

  def index
    authorize MeetingPart
    today = Current.user.today
    shared = MeetingPart.shared_with(Current.household).includes(:user)
    @coming_up = shared.coming_up(today).load
    @earlier = shared.earlier(today).load
  end
end
