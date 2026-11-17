# Settings → Appearance (docs/design/app-shell.md, Theming and appearance). The redirect renders a new <body>, so the
# page takes the new theme as soon as it's saved.
class Settings::AppearancesController < ApplicationController
  include HouseholdScoped

  before_action { authorize @user = Current.user, :update? }

  def show
  end

  def update
    if @user.update(appearance_params)
      redirect_to household_settings_appearance_path, notice: "Your appearance is saved."
    else
      render :show, status: :unprocessable_content
    end
  end

  private
    def appearance_params
      params.expect(user: %i[ appearance ])
    end
end
