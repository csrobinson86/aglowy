# The Appearance section of account settings: its form posts here, and the page is the account settings page.
# The redirect renders a new <body>, so the page takes the new theme as soon as it's saved.
class Accounts::AppearancesController < ApplicationController
  include AccountScoped

  before_action { authorize @user }

  def update
    if @user.update(appearance_params)
      redirect_to edit_account_path, notice: "Your appearance is saved."
    else
      render "accounts/edit", status: :unprocessable_content
    end
  end

  private
    def appearance_params
      params.expect(user: %i[ appearance ])
    end
end
