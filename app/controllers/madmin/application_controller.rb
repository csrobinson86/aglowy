module Madmin
  class ApplicationController < Madmin::BaseController
    before_action :authenticate_staff_identity

    private

    def authenticate_staff_identity
      authenticate_identity!
      redirect_to main_app.root_path, alert: "Not authorized" unless current_identity.staff?
    end
  end
end
