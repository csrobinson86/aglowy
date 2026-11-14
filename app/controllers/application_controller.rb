class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern

  before_action :authenticate_identity!, unless: :devise_controller?
  before_action :set_current_identity
  after_action :verify_authorized, unless: :skip_authorization?

  rescue_from Pundit::NotAuthorizedError, with: :not_authorized

  private

  def set_current_identity
    Current.identity = current_identity
  end

  # Nil outside household URLs; policies for those actions must not read it.
  def pundit_user
    Current.membership
  end

  def not_authorized
    redirect_to (Current.household ? household_root_path : root_path), alert: "You can't do that in this household.", status: :see_other
  end

  def skip_authorization?
    devise_controller?
  end
end
