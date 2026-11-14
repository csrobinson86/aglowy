class Admin::ImpersonationsController < ApplicationController
  skip_after_action :verify_authorized

  before_action :require_staff_not_impersonating, only: :create
  before_action :require_impersonating, only: :destroy

  def create
    identity = Identity.find(params[:identity_id])

    # Devise signs out the current identity if the target can't sign in,
    # which would strand the staff session with no way to stop.
    unless identity.active_for_authentication?
      redirect_to "/madmin", alert: "#{identity.email} can't sign in, so it can't be impersonated"
      return
    end

    staff_identity_id = current_identity.id
    sign_in(:identity, identity)
    session[:staff_identity_id] = staff_identity_id
    redirect_to root_path, notice: "Now impersonating #{identity.email}"
  end

  def destroy
    staff = Identity.find(session.delete(:staff_identity_id))
    sign_in(:identity, staff)
    redirect_to "/madmin", notice: "Stopped impersonating"
  end

  private

  def require_staff_not_impersonating
    redirect_to root_path unless current_identity&.staff? && session[:staff_identity_id].blank?
  end

  def require_impersonating
    redirect_to root_path unless session[:staff_identity_id].present?
  end
end
