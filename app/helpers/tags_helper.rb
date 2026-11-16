module TagsHelper
  # Where a tag's Label goes: the list its thing is in, filtered by the tag (docs/design/tags.md, Filtering lists).
  def tag_filter_path(taggable, tag, household: Current.household)
    if taggable.is_a?(Goal)
      household_my_goals_path(household_id: household, tag: tag.name)
    else
      household_meeting_notes_path(household_id: household, tag: tag.name)
    end
  end
end
