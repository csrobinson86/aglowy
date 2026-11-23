# A person's study guide for one week (docs/design/study-guide.md, StudyGuide): the parts of both meetings the AI wrote,
# and the pages it used. Personal, so it follows the person between households (Trap 3). Filled in by
# User#prepare_study_guide; its chat goes after 7 days, and the guide stays 8 weeks.
class StudyGuide < ApplicationRecord
  # By the week each is for, so a guide stays 8 whole weeks after its own (StudyGuide::PurgeJob).
  KEEP_FOR = 8.weeks

  belongs_to :user
  belongs_to :chat, optional: true
  # The database deletes parts and sources with their guide (on_delete: :cascade).
  has_many :parts, -> { in_order_of(:step, StudyGuide::Part::STEPS.keys) }, inverse_of: :study_guide
  has_many :sources, -> { order(:position) }, inverse_of: :study_guide

  scope :preloaded, -> { includes(:parts, :sources) }
  scope :expired, -> { where(week_of: ...Date.current.beginning_of_week(:monday) - KEEP_FOR) }

  # The parts a reply's fields hold for +steps+, as attributes for StudyGuide::Part: each step once, the first part for
  # it whose content passes the checks before saving (docs/design/study-guide.md, Ai::Purpose::StudyGuide).
  def self.parts_from_reply(fields, steps:, copy_check:)
    parts = Array(fields["parts"]).grep(Hash).select { it["step"].in?(steps) }.filter_map do |part|
      content = StudyGuide::Part::Shape.new(part["step"]).content_from_reply(part["content"], copy_check:)
      { step: part["step"], content: } if content
    end
    parts.uniq { it[:step] }
  end

  # Saves the parts for steps that still have none, never touching a saved part, with the pages not yet linked and the
  # chat that asked. Self, or nil when no part is new: then nothing is saved, and a new guide isn't made.
  def fill_in(new_parts, pages:, chat:)
    new_parts = new_parts.reject { it[:step].in?(parts.map(&:step)) }
    return if new_parts.none?

    new_parts.each { parts.build(it) }
    link(pages)
    update!(chat:)
    self
  end

  # A meeting's parts in step order, its overview first.
  def parts_for(meeting)
    parts.select { it.meeting == meeting }
  end

  # A step of the meeting still has no part: a later run fills it in (docs/design/study-guide.md, How it looks, States).
  def missing_parts?(meeting)
    StudyGuide::Part::STEPS.count { |_, of| of == meeting } > parts_for(meeting).size
  end

  # "Week of November 16–22, 2026", as a meeting note's week reads.
  def display_week
    MeetingNote.new(week_of:).display_week
  end

  # The week's Bible reading, "Lamentations 1–2", from its part; nil while it has none.
  def reading
    parts.find { it.step == "bible_reading" }&.content&.dig("reading")
  end

  # Scriptures in this guide: each one a meeting's parts point to, once, in the order they come.
  def references_for(meeting)
    parts_for(meeting).flat_map(&:references).uniq
  end

  private
    # A page already linked isn't linked twice, and one whose search result has no title is left out, rather than
    # losing the parts to the not-null title.
    def link(pages)
      linked = sources.map(&:url)
      pages.select { it[:title].present? && !it[:url].in?(linked) }
        .each.with_index(sources.size + 1) { |page, position| sources.build(position:, **page.slice(:url, :title)) }
    end
end
