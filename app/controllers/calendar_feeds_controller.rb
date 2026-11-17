# A person's phone calendar, /calendar/<token>.ics (docs/design/calendar.md, The phone feed). A calendar app has no
# session, so the token is the authorization: found only by it, an unknown one is a 404, and it shows only that
# person's view (Trap 5).
class CalendarFeedsController < ApplicationController
  skip_before_action :authenticate_identity!
  skip_after_action :verify_authorized

  rate_limit to: 30, within: 1.minute

  def show
    feed = CalendarFeed.find_by!(token: params[:token])

    expires_in 15.minutes, public: false
    render plain: feed.to_ics, content_type: "text/calendar"
  end

  private
    # The token is in the path, and Lograge logs the path, so the log gets it filtered like the token param.
    def append_info_to_payload(payload)
      super
      payload[:path] = payload[:path].sub(params[:token], "[FILTERED]") if params[:token].present?
    end
end
