# One day's brief for a person, made from a copy of their plan (docs/design/daily-brief.md, DailyBrief). It reads its
# own copy, never the live plan, so editing the plan can't change or break a brief already made (Trap 7). One a day per
# person, by a unique index.
class DailyBrief < ApplicationRecord
  # Today's thought, shared with a household with no notification: it declares none (For the children, and sharing).
  include Shareable

  # A brief takes six requests at most, whatever their endings, as a failed one gives its use back (Trap 14).
  MAX_WRITINGS = 6
  # The evening questions open at 6:00 PM in the person's zone (This evening).
  EVENING_OPENS_AT = 18

  belongs_to :user
  # Oldest first. Deleting a brief deletes its writings' chats, and the database the writings with them.
  has_many :writings, -> { order(:created_at, :id) }, class_name: "DailyBrief::Writing", inverse_of: :daily_brief, dependent: :destroy

  # The sections, the focus areas and that weekday's row, as they were when the brief was made.
  encrypts :plan

  # Kept as long as their writings' chats, only so the next briefs can avoid repeating them (The purpose).
  scope :expired, -> { where(on: ...Ai::Purpose.find(Writing::PURPOSE).keep_for.ago.to_date) }

  # Today's brief (or the day's), found or made under the person's lock: the one Plan#pause takes, so none is made once
  # the plan is paused, though one already made is still found. With pause_if_unseen (the morning job only), a day with
  # no brief after seven unseen in a row pauses the plan instead, in the same lock, so a brief already made today is
  # never a reason to pause. Nil when there's nothing to do: no plan, paused, or paused just now (The morning job).
  def self.for(user, on: user.today, pause_if_unseen: false)
    user.with_lock do
      plan = user.daily_brief_plan or next
      brief = user.daily_briefs.find_by(on:)

      if brief || plan.paused?
        brief
      elsif pause_if_unseen && plan.gone_unseen?(on)
        plan.pause(reason: "unseen")
        nil
      else
        user.daily_briefs.create!(on:, plan: plan.copy_for(on))
      end
    end
  end

  # The AI part, written, with its own chat and its use, then written in the background; or an unsaved writing with an
  # error saying why not: :not_allowed unless it's the person's own brief and they may have AI drafts, :paused while
  # their plan is paused, :written with first: true once the brief has a writing of any status, :busy while one is being
  # written, and :limit at the day's 3 or the brief's 6. Every check runs under the person's lock, the one Plan#pause
  # takes, so two at once make one and can't both take the last one. The job is queued once the lock is let go: it's in
  # another database, and a worker could otherwise start before the writing is committed (How a writing runs).
  def write(by:, first: false)
    writing = by.with_lock do
      reason, message = write_refusal(by, first:)
      next Writing.new(daily_brief: self).tap { it.errors.add(:base, reason, message:) } if reason

      writings.create!(chat: Chat.new(user: by, purpose: Writing::PURPOSE), use: Ai::Use.new(user: by, purpose: Writing::PURPOSE))
    end

    writing.tap { it.write_later if it.persisted? }
  end

  # The newest written writing: what the page shows. "Another angle" adds one, and the earlier stays until the purge.
  def writing
    writings.reverse.find(&:written?)
  end

  # How many more writings it can have today: the person's left of their 3, or the brief's left of its 6, whichever is
  # fewer. Zero is "No more today".
  def writings_left
    [ user.daily_brief_writings_left_today, MAX_WRITINGS - writings.count ].min.clamp(0..)
  end

  # The person's plan is paused, read afresh: brief.write and the writing's job ask under the person's lock.
  def paused?
    DailyBrief::Pause.joins(:plan).exists?(daily_brief_plans: { user_id: })
  end

  def sections
    plan.fetch("sections")
  end

  def section?(name)
    name.to_s.in?(sections)
  end

  # The copy's focus areas and day, as unsaved records, so they read as the plan's do: a topic by its focus area, its
  # scriptures as references.
  def focus_areas
    @focus_areas ||= plan.fetch("focus_areas").map { copied(DailyBrief::FocusArea, it) }
  end

  def day
    @day ||= copied(DailyBrief::Day, plan.fetch("day"))
  end

  def topic_for(focus_area)
    day.topic_for(focus_area)
  end

  def quality_area
    focus_areas.find(&:quality?)
  end

  def appreciation_area
    focus_areas.find(&:appreciation?)
  end

  # "Your focus today": one row each, in the plan's order.
  def role_areas
    focus_areas.select(&:role?)
  end

  # Where the day's reading starts: the chapter it names, "Matthew 5" for "Matthew 5 to John" or "Matthew 5:3–12", or the
  # first chapter of its first book, "Matthew 1" for "Matthew – John". Nil when the box is empty or doesn't start with a book.
  def reading_start
    first = day.reading.to_s.split(/[–—,-]| to /i).first.to_s.sub(/:.*\z/, "")
    Bible::Reference.parse(first) || Bible::Reference.parse("#{first} 1")
  end

  # The newest written writing's questions to end the day, when evening is on in the brief's copy of the plan: 3 or 4
  # (The reply), each with its text and the section it looks back on. None without a written writing.
  def evening_questions
    section?(:evening) ? Array(writing&.section(:evening)) : []
  end

  # From 6:00 PM on the brief's own day, in the person's zone; an earlier day's evening has opened already.
  def evening_open?(now)
    now >= on.in_time_zone(user.calendar_time_zone).change(hour: EVENING_OPENS_AT)
  end

  # The day's text on wol.jw.org, in English. Aglowy links to it and never fetches it.
  def daily_text_url
    "https://wol.jw.org/en/wol/dt/r1/lp-e/#{on.year}/#{on.month}/#{on.day}"
  end

  # The first time the person saw it, on its page: the one fact the pause rule reads (Trap 5). Set once, under the brief's
  # lock, so two pages opened at once keep the first time.
  def mark_seen
    return if seen_at

    with_lock { update!(seen_at: Time.current) unless seen_at }
  end

  # A copy kept as one of the owner's own notes, titled with its date (Keep in Notes, and print). The body is our own
  # partial, every field escaped and every reference a scripture link (Trap 11), from the newest written writing or,
  # with none, the parts from the plan. Nothing links it back, so it stays when the brief is purged; keeping it twice
  # makes two.
  def keep_as_note
    user.personal_notes.new(title: "Daily brief · #{on.strftime("%A, %B %-d")}", body: note_html).tap do |note|
      note.link_scriptures
      note.save!
    end
  end

  private
    def notifies_when_shared? = false

    def note_html
      ApplicationController.render(partial: "daily_briefs/note", locals: { brief: self, writing: })
    end

    def write_refusal(by, first:)
      if by != user || !(by.may_have_daily_brief? && by.accepted_ai_terms?)
        [ :not_allowed, "Only you, as a head or adult with AI drafts turned on, can have your brief written" ]
      elsif paused?
        [ :paused, "Your daily brief is paused" ]
      elsif first && writings.exists?
        [ :written, "This brief has been written already" ]
      elsif writings.writing.exists?
        [ :busy, "This brief is being written" ]
      elsif writings_left.zero?
        [ :limit, "No more today" ]
      end
    end

    # Only the columns the record still has, so a brief kept from before a column changed still reads.
    def copied(model, attributes)
      model.new(attributes.slice(*model.attribute_names)).tap(&:readonly!)
    end
end
