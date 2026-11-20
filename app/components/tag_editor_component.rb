# frozen_string_literal: true

# The owner's tags on one of their meeting notes or personal goals, under its title (docs/design/tags.md, The tag
# editor; frame personal-study.png): each tag a Label with its remove button, then "Add a tag", which suggests the
# person's own tags with their counts. Renders nothing for anyone else, or on a family goal, so a shared view can't
# show tags. On a note that isn't saved yet, adding and removing change only the page, and the note's form sends the
# names with the note (docs/design/tags.md, The tag editor, on a note that isn't saved yet).
class TagEditorComponent < ApplicationComponent
  attr_reader :taggable, :user, :household, :error

  # error: why the last tag couldn't be added, shown with the input. focus: put focus in the input, after adding or
  # removing. tag_names: on an unsaved note, the names it shows, as typed, after a refused save.
  def initialize(taggable:, user:, household:, error: nil, focus: false, tag_names: [])
    @taggable = taggable
    @user = user
    @household = household
    @error = error
    @focus = focus
    @tag_names = tag_names
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

  def unsaved?
    taggable.new_record?
  end

  # Its current value: the names as typed on an unsaved note, its tags' names on a saved one.
  def names
    unsaved? ? @tag_names : tags.map(&:name)
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

  # A name on an unsaved note: a plain Label, since it has no tag page yet, and a button that takes it off the page.
  # The tag-editor controller clones a blank one for each name added.
  def unsaved_tag(name)
    tag.span(class: "d-inline-flex flex-items-center mr-1", data: { tag_editor_target: "tag" }) do
      render(Primer::Beta::Label.new(scheme: :accent).with_content("##{name}")) +
        render(Primer::Beta::IconButton.new(icon: :x, scheme: :invisible, size: :small, show_tooltip: false, "aria-label": "Remove tag #{name}", data: { action: "tag-editor#remove" }))
    end
  end
end
