# Settings → Notifications, for every role: which kinds also come by email or to their phone, quiet hours, and their
# phones and browsers
# (docs/design/notifications.md, Settings → Notifications). It saves the person, never Current.membership
# (docs/design/settings.md, Traps).
class Settings::NotificationsController < ApplicationController
  include HouseholdScoped

  before_action { authorize @user = Current.user, :update? }

  def show
  end

  # Replaces the person's settings with the boxes ticked. Only the kinds they're offered are read from the form, and
  # the model keeps only the channels they're offered, so a child's email is never saved.
  def update
    @user.notification_settings.change(chosen_pairs)
    redirect_to household_settings_notifications_path, notice: "Your notifications are saved."
  end

  private
    # notification_settings[weekly_preview][]=email becomes [ "weekly_preview", "email" ]. Nothing ticked sends nothing,
    # and neither does anything that isn't the form's hash of kinds: permit lets a list of hashes through as a list.
    def chosen_pairs
      settings = params[:notification_settings]
      return [] unless settings.is_a?(ActionController::Parameters)

      settings.permit(@user.notification_kinds.to_h { [ it.name, [] ] }).to_h.flat_map { |kind, channels| [ kind ].product(channels) }
    end
end
