class DesignSystemController < ApplicationController
  skip_before_action :authenticate_identity!
  skip_after_action :verify_authorized

  layout "design_system"

  def show
  end
end
