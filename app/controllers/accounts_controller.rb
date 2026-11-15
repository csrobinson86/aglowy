# The Profile section of account settings, at /account. Both sections render on this page.
class AccountsController < ApplicationController
  include AccountScoped

  before_action { authorize @user }

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to edit_account_path(return_to_params), notice: "Your profile is saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def user_params
      params.expect(user: %i[ name time_zone ])
    end
end
