module StudyGuidesHelper
  # Home's and the meeting note's links to the study guide, for a head or adult here with theirs on
  # (docs/design/study-guide.md, Where people find it). The sidebar asks the same of its membership.
  def study_guide_on_here?
    policy(:study_guide).index? && Current.user.study_guide_on?
  end
end
