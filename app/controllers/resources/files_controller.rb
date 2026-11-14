# The only way to a file resource: found through the household, authorized, then redirected to the
# storage service's URL, which expires in five minutes (gotcha 22).
class Resources::FilesController < ApplicationController
  include HouseholdScoped
  include ActiveStorage::SetCurrent

  def show
    resource = Current.household.family_study_resources.file.find(params[:resource_id])
    authorize resource, :show?

    # Production storage will be another host (the deploy epic).
    redirect_to resource.file.url, allow_other_host: true
  end
end
