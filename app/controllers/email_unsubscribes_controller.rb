# "Turn off this email", from an email's footer (show, a page with one button, so a mail scanner that follows links
# turns nothing off) and from the mail client's one-click POST (create, which the button posts too)
# (docs/design/notifications.md, Emails). Nobody needs to be signed in and Current.user is never read: the person is
# found only by the signed token, checked with the purpose its scope names. So the token stands in for the policy, and
# for the CSRF token the mail client's POST can't have. Nothing else in the app skips forgery protection.
class EmailUnsubscribesController < ApplicationController
  layout "focused"

  skip_before_action :authenticate_identity!
  skip_after_action :verify_authorized
  skip_forgery_protection only: :create

  before_action :set_user

  helper_method :email_name

  def show
  end

  def create
    @user.unsubscribe_from_email(params[:scope])
  end

  private
    # An unknown scope, or a bad or wrong-scope token, changes nothing and says nothing about anyone.
    def set_user
      @user = User.find_by_unsubscribe_token(params[:scope], params[:token])
      render :invalid, status: :not_found unless @user
    end

    # A mail client's one-click POST, or a person on an old phone, must still be able to turn an email off.
    def any_browser?
      true
    end

    # The token is in the path, and Lograge logs the path, so the log gets it filtered like the token param
    # (CalendarFeedsController does the same). The whole last segment goes, however it was encoded.
    def append_info_to_payload(payload)
      super
      payload[:path] = payload[:path].sub(%r{\A(/unsubscribe/[^/?]+)/[^/?]+}, '\1/[FILTERED]')
    end

    # What the link turns off, as the page says it: "your daily summary email" or "Weekly preview emails".
    def email_name
      params[:scope] == "summary" ? "your daily summary email" : "#{Notification::Kind.all.find { it.name == params[:scope] }.label} emails"
    end
end
