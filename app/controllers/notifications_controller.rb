# The inbox, from every household the person is in, and opening one (docs/design/notifications.md, The inbox). Always
# through Current.user.notifications.visible, so someone else's notification, or one from a household they left, is a
# 404. The household in the URL is only where the page is shown.
class NotificationsController < ApplicationController
  include HouseholdScoped

  PAGE_SIZE = 50

  # ?show=unread lists only unread ones; All is the default.
  def index
    authorize Notification
    @unread_only = params[:show] == "unread"
    @unread_count = notifications.unread.count
    @page = Page.new((@unread_only ? notifications.unread : notifications).preloaded.newest_first, number: params[:page], size: PAGE_SIZE)
    # Reading the last unread one on a later page leaves it empty: show the last page that has some.
    redirect_to household_notifications_path(show: params[:show].presence, page: (@page.last_number if @page.last_number > 1)) if @page.past_the_end?
  end

  # Opening it is the only way one is read, so a mail scanner following an email's link reads nothing (Trap 5). It
  # opens under its own household, which can be another one than this page's.
  def show
    @notification = notifications.find(params[:id])
    authorize @notification
    @notification.read
    redirect_to @notification.target_path
  end

  private

  def notifications
    Current.user.notifications.visible
  end
end
