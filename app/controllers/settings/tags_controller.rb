# Settings → Tags and collections: the person's own tags and collections, renamed, edited and deleted through
# TagsController and CollectionsController, which return here (docs/design/settings.md, Tags and collections).
class Settings::TagsController < ApplicationController
  include HouseholdScoped

  def index
    authorize Tag
    @tags = Current.user.tags.with_taggings_count.order(:name)
    @collections = Current.user.collections.with_contents_counts.positioned
  end
end
