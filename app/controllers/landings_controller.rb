class LandingsController < ApplicationController
  # A redirect with no record behind it, so there is nothing to authorize.
  skip_after_action :verify_authorized

  def show
    redirect_to after_sign_in_path_for(current_identity)
  end
end
