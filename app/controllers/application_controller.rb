class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern

  layout :layout_for_request

  before_action :authenticate_identity!, unless: :devise_controller?
  before_action :set_current_identity
  after_action :verify_authorized, unless: :skip_authorization?

  rescue_from Pundit::NotAuthorizedError, with: :not_authorized

  private

  def set_current_identity
    Current.identity = current_identity
  end

  # Only active memberships count: none, one, or several households.
  def after_sign_in_path_for(identity)
    households = identity.user.active_households.limit(2).to_a

    stored_location_for(identity) ||
      case households.size
      when 0 then new_household_path
      when 1 then household_root_path(household_id: households.first)
      else households_path
      end
  end

  # Nil outside household URLs; policies for those actions must not read it.
  def pundit_user
    Current.membership
  end

  def not_authorized
    redirect_to (Current.household ? household_root_path : root_path), alert: "You can't do that in this household.", status: :see_other
  end

  # Devise's pages have no household (docs/design/app-shell.md, Two layouts).
  # Rails' layout takes no if:, so a method picks it.
  def layout_for_request
    devise_controller? ? "focused" : "application"
  end

  def skip_authorization?
    devise_controller?
  end
end
