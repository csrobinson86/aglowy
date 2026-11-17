# Turn on for this browser, and Remove, in Settings → Notifications' Phones and browsers (docs/design/notifications.md).
# Always the signed-in person's own devices, so someone else's is a 404. The push_subscription Stimulus controller fills
# in and submits the create form once the browser has subscribed.
class PushSubscriptionsController < ApplicationController
  include HouseholdScoped

  def create
    authorize PushSubscription
    Current.user.push_subscriptions.subscribe(**subscription_params, user_agent: request.user_agent)
    redirect_to household_settings_notifications_path, notice: "Notifications are on for this browser."
  rescue ActiveRecord::RecordInvalid
    redirect_to household_settings_notifications_path, alert: "Notifications couldn't be turned on for this browser."
  end

  def destroy
    authorize subscription = Current.user.push_subscriptions.find(params[:id])
    subscription.destroy!
    redirect_to household_settings_notifications_path, notice: "#{subscription.label} is removed.", status: :see_other
  end

  private
    def subscription_params
      endpoint, p256dh_key, auth_key, standalone = params.expect(push_subscription: %i[ endpoint p256dh_key auth_key standalone ]).values_at(:endpoint, :p256dh_key, :auth_key, :standalone)
      { endpoint:, p256dh_key:, auth_key:, standalone: ActiveModel::Type::Boolean.new.cast(standalone) }
    end
end
