class SignupsController < ApplicationController
  skip_before_action :authenticate_identity!
  skip_after_action :verify_authorized

  def new
    @signup = Signup.new
  end

  def create
    @signup = Signup.new(signup_params)

    if @signup.save
      redirect_to new_identity_session_path, notice: "Check your email to confirm your account."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def signup_params
    params.expect(signup: %i[ name email password household_name time_zone ])
  end
end
