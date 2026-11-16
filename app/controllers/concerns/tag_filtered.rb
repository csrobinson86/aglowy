# A list that takes ?tag=<name> (docs/design/tags.md, Filtering lists). The tag is found through Current.user.tags, so
# another person's tag name, like one that doesn't exist, filters the list to nothing.
module TagFiltered
  extend ActiveSupport::Concern

  included do
    before_action :set_tag_name, only: :index
  end

  private

  # "#Ministry" filters by ministry; one that normalizes to nothing doesn't filter.
  def set_tag_name
    @tag_name = Tag.normalize(params[:tag]).presence
  end

  def tagged(relation)
    return relation unless @tag_name

    tag = Current.user.tags.find_by(name: @tag_name)
    tag ? relation.tagged_with(tag) : relation.none
  end
end
