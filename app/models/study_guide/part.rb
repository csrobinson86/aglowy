# One part of a week's study guide (docs/design/study-guide.md, StudyGuide::Part): an overview of a meeting, or a part of
# its program, in the AI's own words with references. Its fields are encrypted JSON, so the database can't see them:
# the model checks them against the step's shape (StudyGuide::Part::Shape). Untrusted text: always escaped when shown
# (Trap 5).
class StudyGuide::Part < ApplicationRecord
  # The steps in the guide's order, each meeting's overview first, and their meeting.
  # Keep in step with the study_guide_parts_step_check constraint.
  STEPS = { "midweek_overview" => "midweek", "talk" => "midweek", "spiritual_gems" => "midweek", "bible_reading" => "midweek",
            "field_ministry" => "midweek", "living" => "midweek", "congregation_bible_study" => "midweek",
            "weekend_overview" => "weekend", "watchtower_study" => "weekend" }.freeze

  belongs_to :study_guide

  serialize :content, coder: JSON
  encrypts :content

  validate :content_fits_its_step

  def meeting
    STEPS[step]
  end

  def overview?
    step.end_with?("_overview")
  end

  # The scripture each point ends with, from its saved ref, which parsed when it was saved: a whole chapter, "Psalm 23",
  # as well as verses. Never through Bible::Linker, which links verses only (docs/design/study-guide.md, A part's card).
  def references
    points.filter_map { Bible::Reference.parse(it["ref"]) }
  end

  # The points of a list, none when the part has no such list.
  def points(list = nil)
    list ? Array(content[list]) : content.values.grep(Array).flatten
  end

  private
    def content_fits_its_step
      errors.add(:content, "doesn't fit the #{step} step") unless step.in?(STEPS) && Shape.new(step).fits?(content)
    end
end
