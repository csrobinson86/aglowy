class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern

  before_action :set_current_identity
  after_action :verify_authorized, unless: :skip_authorization?

  private

  def set_current_identity
    Current.identity = current_identity
  end

  def skip_authorization?
    devise_controller?
  end
end
