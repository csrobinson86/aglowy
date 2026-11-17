# frozen_string_literal: true

# The owner's tags on one of their meeting notes or personal goals, under its title (docs/design/tags.md, The tag
# editor; frame personal-study.png): each tag a Label with its remove button, then "Add a tag", which suggests the
# person's own tags with their counts. Renders nothing for anyone else, or on a family goal, so a shared view can't
# show tags.
class TagEditorComponent < ApplicationComponent
  attr_reader :taggable, :user, :household, :error

  # error: why the last tag couldn't be added, shown with the input. focus: put focus in the input, after adding or removing.
  def initialize(taggable:, user:, household:, error: nil, focus: false)
    @taggable = taggable
    @user = user
    @household = household
    @error = error
    @focus = focus
  end

  def render?
    taggable.taggable_by?(user)
  end

  def id
    dom_id(taggable, :tag_editor)
  end

  def focus?
    @focus
  end

  def tags
    @tags ||= taggable.tags_for(user).sort_by(&:name)
  end

  # The person's other tags, never anyone else's (docs/design/tags.md, Traps).
  def suggestions
    user.tags.with_taggings_count.where.not(id: tags).order(:name)
  end

  def taggings_path
    helpers.polymorphic_path([ :household, taggable, :taggings ], household_id: household.id)
  end

  def tagging_path(tag)
    helpers.polymorphic_path([ :household, taggable, :tagging ], id: tag.id, household_id: household.id)
  end

  def tag_page_path(tag)
    helpers.household_tag_path(household_id: household.id, name: tag.name)
  end
end
