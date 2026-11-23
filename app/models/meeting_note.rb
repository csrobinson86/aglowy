# One person's notes from one meeting in one week, part by part on the meeting's outline.
# Personal content: it belongs to its author, never to a household (docs/design/meeting-notes.md).
class MeetingNote < ApplicationRecord
  include Shareable, Taggable

  PROGRAM_URL = "https://wol.jw.org/en/wol/meetings/r1/lp-e"
  TITLES = { "midweek" => "Life and Ministry", "weekend" => "Weekend meeting" }.freeze

  belongs_to :user
  has_many :parts, -> { order(:position) }, dependent: :destroy
  has_many :gems, -> { order(:position) }, dependent: :delete_all
  has_many :marks, dependent: :delete_all
  # The listening game's finds, each step's in round order (docs/design/listening-game.md, MeetingNote::Find).
  has_many :finds, -> { order(:step, :position) }, dependent: :delete_all
  # Her answer for the Congregation Bible Study (docs/design/listening-game.md, MeetingNote::Answer).
  has_one :answer, dependent: :delete
  # Destroyed one by one, so their images are purged.
  has_many :drawings, dependent: :destroy
  # Deleting the note takes its "shared with you" notifications with it (docs/design/notifications.md, Models).
  has_many :notifications, as: :subject, dependent: :delete_all

  # Only Living as Christians parts can be removed (only_repeating_parts_removed); new ones come from revise!.
  accepts_nested_attributes_for :parts, allow_destroy: true
  accepts_nested_attributes_for :gems, allow_destroy: true

  enum :kind, %w[ midweek weekend ].index_by(&:itself), validate: true

  # Also applies to lookups, so start_meeting_note finds the note from any day of its week.
  normalizes :week_of, with: -> { it.to_date.beginning_of_week(:monday) }

  validates :week_of, presence: true
  validate :only_repeating_parts_removed

  scope :preloaded, -> { includes(:user, :gems, :shared_households, :marks, :finds, :answer, drawings: { image_attachment: :blob }, parts: :rich_text_notes) }
  scope :newest_first, -> { order(week_of: :desc, kind: :desc) }
  # Grouped a week at a time, newest week first, with Life and Ministry before the weekend in each week
  # (docs/design/notes.md, Earlier, a week at a time).
  scope :in_week_order, -> { reorder(week_of: :desc, kind: :asc, created_at: :asc) }
  # The distinct weeks with notes, newest first, so a Page counts weeks, not notes.
  scope :weeks, -> { unscope(:includes).select(:week_of).distinct.reorder(week_of: :desc) }

  def outline
    Outline.new(kind: kind, version: outline_version)
  end

  # The meeting helper's steps for this note's kind (docs/design/meeting-helper.md).
  def helper_steps
    HelperSteps.for(kind)
  end

  # "I heard it!" on a step, by its key. create_or_find_by! leans on the unique index, so a double tap
  # finds the first mark instead of raising.
  def mark(step)
    marks.create_or_find_by!(step: step)
  end

  # Resets the marks, so marked? doesn't answer from ones loaded before.
  def unmark(step)
    marks.where(step: step).delete_all
    marks.reset
  end

  # Reads the loaded marks, so the step dots ask once for the whole note.
  def marked?(step)
    marks.any? { it.step == step }
  end

  # Tapping a card in a round of the listening game. The answer card makes a find, copying the card's label and kind;
  # create_or_find_by! leans on the unique index, so a double tap finds the first (Trap 6). Any other card saves nothing
  # and returns nil: a wrong tap costs nothing.
  def find_card(card)
    return unless card.answer?

    finds.create_or_find_by!(step: card.round.step, position: card.round.position) { it.assign_attributes(card.slice(:label, :kind)) }
  end

  # Reads the loaded finds, like marked?.
  def found?(round)
    finds.any? { it.step == round.step && it.position == round.position }
  end

  # The score for this meeting only (docs/design/listening-game.md, Decisions).
  def found_count
    finds.size
  end

  def finds_for(step)
    finds.select { it.step == step }
  end

  # The finds in the helper's step order; the association's order is by the step's key.
  def finds_in_step_order
    helper_steps.flat_map { finds_for(it.key) }
  end

  # The round a step opens at: the first she hasn't found, or the last once she's found them all.
  def current_round(rounds)
    rounds.find { !found?(it) } || rounds.last
  end

  # Saves her answer, the first or a change. create_or_find_by leans on the unique index, so two first saves at once
  # make one answer. Returns the answer, with errors when it's refused.
  def write_answer(attributes)
    written = Answer.create_or_find_by(meeting_note: self) { it.assign_attributes(attributes) }
    written.update(attributes) if written.persisted? && !written.previously_new_record?
    written
  end

  # The mark button's words: on the Bible Study step, once she has an answer, "I gave my answer!" / "Gave my answer"
  # instead of "I watched!" (docs/design/listening-game.md, MeetingNote::Answer).
  def mark_label(step)
    answered?(step) ? "I gave my answer!" : step.mark_label
  end

  def marked_label(step)
    answered?(step) ? "Gave my answer" : step.marked_label
  end

  def answered?(step)
    step.answerable? && answer.present?
  end

  # Saves the step's drawing, replacing the one before (whose image Active Storage purges). create_or_find_by
  # leans on the unique index, so two saves at once can't make two; the row lock makes the second replacement wait
  # and reload, so it replaces the first's image instead of both being kept. Returns the drawing, with errors when
  # the image isn't a small PNG. The upload's declared type and file name are dropped, so Active Storage judges the
  # type by the bytes alone: bytes it can't recognise are application/octet-stream, never a PNG (Trap 8).
  def draw(step, upload)
    image = { io: upload.to_io, filename: "drawing" } if upload.present?
    drawing = drawings.create_or_find_by(step: step) { it.image = image }
    drawing.with_lock { drawing.update(image: image) } if drawing.persisted? && !drawing.previously_new_record?
    drawing
  end

  # Reads the loaded drawings, like marked?. A refused first save leaves its unsaved drawing among them.
  def drawn?(step)
    drawings.any? { it.persisted? && it.step == step }
  end

  # True once the child marked, drew, found or wrote anything in Today's meeting. Reads the loaded records, like marked?.
  def helper_used?
    marks.any? || drawings.any?(&:persisted?) || finds.any? || answer.present?
  end

  # Up to three "Talk about it" questions for a parent to ask (docs/design/meeting-helper.md): drawn steps first, then
  # up to two finds and her answer (docs/design/listening-game.md, Pages), then marked steps, each in step order. A drawn
  # step asks about the drawing, never guessing what's in it; a given answer asks about the answer, not the pictures.
  def talk_questions
    drawn = helper_steps.select { drawn?(it.key) }
    marked = helper_steps.select { marked?(it.key) && !drawn?(it.key) && !answered?(it) }
    [ *drawn.map { "Tell me about your drawing of #{it.short_title.downcase}." },
      *finds_in_step_order.first(2).map { "You found #{it.label}. What do you remember about it?" },
      *("Tell me about your answer for paragraph #{answer.paragraph}." if answer),
      *marked.map(&:talk_question) ].first(3)
  end

  # Builds every part the outline starts with, in order; a repeating part starts with one.
  def build_parts
    outline.parts.each.with_index(1) { |part, position| parts.build(key: part.key, position: position) }
  end

  # Saves the edit form: titles and notes, with Living as Christians parts and gems added and removed.
  # A part added in the form is always a Living as Christians part, numbered after the others; a new
  # gem is numbered after the other gems. Keys and positions never come from the form. A block is given the note
  # once the form's values are in, before saving.
  def revise!(attributes)
    assign_attributes(attributes)
    yield self if block_given?
    number_new(parts) { |part, position| part.assign_attributes(key: "living_part", position: position) }
    number_new(gems) { |gem, position| gem.position = position }
    save!
  end

  # The parts the person has written something in. Gems are counted on their own.
  def filled_parts
    parts.select(&:filled?)
  end

  # Each outline section with its filled parts in the outline's order, leaving out sections with none.
  # A part added later has the highest position, but still comes before the Congregation Bible Study.
  # Spiritual Gems counts as filled when the note has gems.
  def filled_sections
    shown = parts.select { it.filled? || (it.key == "spiritual_gems" && gems.any?) }
    outline.sections.filter_map do |section|
      keys = section.parts.map(&:key)
      filled = shown.select { keys.include?(it.key) }.sort_by { [ keys.index(it.key), it.position ] }
      [ section, filled ] if filled.any?
    end
  end

  # The author's own meeting parts in a midweek note's week, soonest first, for the lines under its header. The page shows
  # them only to the author, never on a note someone else shared (docs/design/meeting-parts.md, On the calendar and the
  # meeting note).
  def meeting_parts
    midweek? ? user.meeting_parts.where(meeting_on: week_of...week_of + 7).order(:meeting_on, :created_at) : MeetingPart.none
  end

  # The week's program on wol.jw.org, by ISO week: week 27 of 2026 is 29 June–5 July. A meeting part links to it too.
  def self.program_url(week_of)
    "#{PROGRAM_URL}/#{week_of.cwyear}/#{week_of.cweek}"
  end

  def program_url
    self.class.program_url(week_of)
  end

  # "Week of November 16–22, 2026", or "Weekend of November 21–22, 2026".
  def display_week
    weekend? ? "Weekend of #{date_range(week_of + 5, week_of + 6)}" : "Week of #{date_range(week_of, week_of + 6)}"
  end

  private
    def number_new(records, &assign)
      last = records.reject(&:new_record?).map(&:position).max.to_i
      records.select(&:new_record?).each.with_index(last + 1, &assign)
    end

    def only_repeating_parts_removed
      parts.select(&:marked_for_destruction?).reject(&:repeats?).each { errors.add(:parts, "can't lose #{it.label}") }
    end

    def date_range(first, last)
      if first.year != last.year
        "#{first.strftime("%B %-d, %Y")}–#{last.strftime("%B %-d, %Y")}"
      elsif first.month != last.month
        "#{first.strftime("%B %-d")}–#{last.strftime("%B %-d, %Y")}"
      else
        "#{first.strftime("%B %-d")}–#{last.strftime("%-d, %Y")}"
      end
    end
end
