# Creates the blob the drop zone uploads to, after refusing a file over the size limit or outside
# the allowlist before any bytes go up (gotcha 24). Active Storage's controllers don't inherit
# ApplicationController, so sign-in, the household and the policy check are set up here.
class DirectUploadsController < ActiveStorage::DirectUploadsController
  include Pundit::Authorization

  before_action :authenticate_identity!
  before_action { Current.identity = current_identity }
  include HouseholdScoped
  before_action { authorize FamilyStudy::Resource, :create? }
  after_action :verify_authorized

  rescue_from(Pundit::NotAuthorizedError) { head :forbidden }

  def create
    if (problem = FamilyStudy::Resource::FileCheck.new(**blob_args.slice(:content_type, :byte_size)).problem)
      render json: { error: "#{problem.upcase_first}." }, status: :unprocessable_content
    else
      super
    end
  end

  private

  def pundit_user
    Current.membership
  end
end
