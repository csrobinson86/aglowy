# Quiet hours, on Settings → Notifications (docs/design/notifications.md, Settings → Notifications). A refused save
# shows the section again with the error by the field.
class Settings::QuietHoursController < ApplicationController
  include HouseholdScoped

  before_action { authorize @user = Current.user, :update? }

  def update
    if @user.update(quiet_hours_params)
      redirect_to household_settings_notifications_path, notice: "Your quiet hours are saved."
    else
      render "settings/notifications/show", status: :unprocessable_content
    end
  end

  private
    def quiet_hours_params
      params.expect(user: %i[ quiet_hours_start quiet_hours_end ])
    end
end
