# frozen_string_literal: true

# A part's card in the study guide (docs/design/study-guide.md, A part's card; frames desktop-guide-midweek.png and
# desktop-guide-weekend.png): its name and length in small print with its tone dot, its title as an h2, a summary, then
# its labelled rows of points, each ending with its scripture link. Everything in it is the AI's, escaped (Trap 5).
class StudyGuides::PartComponent < ApplicationComponent
  # The program's set lengths; the others vary week to week, and the Bible Reading shows its passage instead.
  MINUTES = { "talk" => 10, "spiritual_gems" => 10, "congregation_bible_study" => 30, "watchtower_study" => 60 }.freeze
  # The title for a part without its own, as Spiritual Gems and the Bible Reading never have one.
  TITLES = { "spiritual_gems" => "Ideas for comments", "bible_reading" => "The Bible reading" }.freeze
  STUDY_ROWS = { "notes" => "Notes", "jehovah" => "About Jehovah", "comments" => "Comment ideas" }.freeze
  APPLY_ROWS = { "apply" => "How we can apply it" }.freeze
  # Each step's lists, by their label on the card, in the card's order.
  ROWS = {
    "talk" => { "points" => "Main points", "jehovah" => "About Jehovah" },
    "spiritual_gems" => { "comments" => "Comment ideas" },
    "bible_reading" => { "happens" => "What happens", "teaches" => "What it teaches about Jehovah", "apply" => "How we can apply it" },
    "field_ministry" => APPLY_ROWS,
    "living" => APPLY_ROWS,
    "congregation_bible_study" => STUDY_ROWS,
    "watchtower_study" => STUDY_ROWS
  }.freeze

  attr_reader :part

  def initialize(part:)
    @part = part
    @step = MeetingNote::HelperSteps.for(part.meeting).fetch(part.step)
  end

  def color = @step.color

  # "Treasures From God's Word · 10 min.", or "Bible Reading · Lamentations 1–2".
  def kicker
    extra = part.step == "bible_reading" ? part.content["reading"] : MINUTES[part.step]&.then { "#{it} min." }
    [ @step.title, extra ].compact.join(" · ")
  end

  def title
    part.content["title"] || TITLES.fetch(part.step, @step.title)
  end

  def summary = part.content["summary"]

  # [label, points] for each list with a point.
  def rows
    ROWS.fetch(part.step).filter_map { |list, label| [ label, part.points(list) ] if part.points(list).any? }
  end

  # "¶4–7: " before a study's note, "¶5: " before its comment idea.
  def paragraphs(point)
    point.values_at("paragraphs", "paragraph").compact.first&.then { "¶#{it}: " }
  end

  def reference(point)
    Bible::Reference.parse(point["ref"])
  end
end
