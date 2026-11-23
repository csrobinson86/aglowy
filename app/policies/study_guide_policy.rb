# A study guide is its owner's alone, read under a head or adult membership in the household in the URL: a child
# membership here is refused even when the person is an adult elsewhere (docs/design/study-guide.md, Who can do what).
# The record is :study_guide for the list, or a StudyGuide. StudyGuidesController answers 404 when it fails.
class StudyGuidePolicy < ApplicationPolicy
  def index? = head_or_adult?

  def show? = head_or_adult? && record.user_id == membership.user_id
end
