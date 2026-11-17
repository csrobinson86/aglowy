# Notification emails, for those who turned them on (docs/design/notifications.md, Emails). They carry titles, dates
# and names, never the text of a note or a study, and nothing that tracks: no images, and every link goes straight to
# Aglowy. Each has the one-click unsubscribe headers (RFC 8058) for what the email was.
class NotificationMailer < ApplicationMailer
  helper_method :unsubscribe_url, :notification_settings_url, :preview

  # A right-away kind: the weekly preview, or a family study that needs a topic. Its template is named for the kind.
  def notification(notification)
    @notification = notification
    @household = notification.household
    @open_url = household_notification_url(@household, notification)

    mail_to notification.user, scope: notification.kind, subject: notification.email_subject, template_name: notification.kind
  end

  # Everything that waited for the daily summary, a row each. The links open the first one's household, where the
  # inbox shows them all.
  def daily_summary(user, notifications)
    @notifications = notifications.to_a
    @household = @notifications.first.household
    @open_url = household_notifications_url(@household)

    mail_to user, scope: "summary", subject: "Your Aglowy summary: #{@notifications.size} new"
  end

  private
    def mail_to(user, scope:, subject:, **options)
      @user = user
      @scope = scope
      headers["List-Unsubscribe"] = "<#{unsubscribe_url}>"
      headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"

      mail to: user.identity.email, subject:, **options
    end

    # Signed for this person and this scope only, so a weekly preview's link can't turn off the summary.
    def unsubscribe_url
      @unsubscribe_url ||= email_unsubscribe_url(scope: @scope, token: @user.unsubscribe_token(@scope))
    end

    def notification_settings_url
      household_settings_notifications_url(@household)
    end

    # The week a weekly preview lists, built from the calendar when the email is written, never stored.
    def preview
      @preview ||= Household::WeeklyPreview.new(@household, week_of: Date.parse(@notification.data.fetch("week_of")))
    end
end
