# What a person's daily brief is built from each morning: their focus areas, a week of rows, which sections are in
# every brief and when it's ready (docs/design/daily-brief.md, DailyBrief::Plan). One per person; it follows them
# between households.
class DailyBrief::Plan < ApplicationRecord
  # Keep in step with daily_brief_plans_sections_check and the column's default.
  SECTIONS = %w[ daily_text reading faith_example children evening ].freeze
  # "Ready by", 4:00 to 8:00 AM on the half hour (daily_brief_plans_ready_at_minutes_check).
  READY_AT_MINUTES = (240..480).step(30).to_a.freeze

  belongs_to :user
  has_many :focus_areas, -> { order(:position) }, inverse_of: :plan, dependent: :delete_all
  has_many :days, -> { order(:wday) }, inverse_of: :plan, dependent: :delete_all
  # Not :pause, which is the method that makes it.
  has_one :pausing, class_name: "DailyBrief::Pause", inverse_of: :plan, dependent: :delete

  scope :preloaded, -> { includes(:focus_areas, :days, :pausing) }
  scope :unpaused, -> { where.missing(:pausing) }

  # The starter's key, on Start's form only.
  attribute :starter, :string

  # Unticked boxes send only the empty value that says the form was sent.
  normalizes :sections, with: -> { it.compact_blank }

  validates :ready_at_minutes, inclusion: { in: READY_AT_MINUTES, message: "Choose a time from 4:00 to 8:00 AM, on the half hour" }
  validate :sections_offered

  # Makes the plan, its focus areas and its seven days from a DailyBrief::Starter in one transaction, or returns an
  # unsaved plan with an error on starter. Someone who already has a plan keeps it: the unique index on user_id refuses
  # a second, from a second tab or a double submit, and their plan is returned unchanged. A savepoint, so a caller's
  # own transaction carries on after the refusal.
  def self.start(user, starter:)
    plan = new(user:, starter:, started_at: Time.current)
    details = DailyBrief::Starter.find(starter) or return plan.tap { it.errors.add(:starter, "Choose a plan to start from") }

    transaction(requires_new: true) do
      plan.save!
      plan.fill_from(details)
    end
    plan
  rescue ActiveRecord::RecordNotUnique
    user.reload.daily_brief_plan or raise
  end

  # "5:00 AM".
  def ready_by(minutes = ready_at_minutes)
    Time.utc(2000).advance(minutes:).strftime("%-l:%M %p")
  end

  # Adds a focus area at the end, or returns it unsaved with the reasons. Under the plan's lock, so two tabs adding at
  # once can't pass six at most, take the same position, or both slip a quality past the friendly check.
  def add_focus_area(attributes)
    with_lock { focus_areas.create(attributes) }
  end

  # Pauses the plan, or finds the pause it already has, under the person's lock: the one DailyBrief.for and
  # brief.write take, so neither makes a brief or starts a writing once it's paused (docs/design/daily-brief.md,
  # DailyBrief::Pause). In the same lock it stops any of the person's writings still being written; each keeps its use,
  # as a Stop does, and a job that hasn't sent its request yet then sends nothing.
  def pause(reason:)
    user.with_lock do
      DailyBrief::Writing.writing.joins(:daily_brief).where(daily_briefs: { user_id: }).update_all(status: "stopped", updated_at: Time.current)
      reload_pausing || create_pausing!(reason:)
    end
  end

  def paused?
    pausing.present?
  end

  # Starts a paused plan again from now, so the briefs that went unseen before the pause can't pause it again, and the
  # job's next brief is tomorrow morning's (Trap 13). A plan that isn't paused keeps its started_at. True when it started
  # it again.
  def resume
    user.with_lock do
      if reload_pausing
        pausing.destroy!
        reset_pausing
        update!(started_at: Time.current)
      else
        false
      end
    end
  end

  # The morning job makes today's brief from 45 minutes before ready-by, in the person's zone, once the plan has run
  # past the day it was started or started again (Trap 13), while it isn't paused and today's brief isn't prepared.
  def due?(now = Time.current)
    local = now.in_time_zone(user.calendar_time_zone)

    !paused? && local.to_date > started_at.in_time_zone(local.time_zone).to_date &&
      minutes_into(local) >= ready_at_minutes - 45 && !prepared?(local.to_date)
  end

  # Ready-by has come today, in the person's zone: the page offers "Prepare today's brief" when there's none yet.
  def ready?(now = Time.current)
    minutes_into(now.in_time_zone(user.calendar_time_zone)) >= ready_at_minutes
  end

  # Today's brief in the person's zone, for their card on Home; none while the plan is paused (docs/design/daily-brief.md,
  # On Home).
  def todays_brief
    user.daily_briefs.find_by(on: user.today) unless paused?
  end

  # Seven briefs in a row the person never saw: the newest seven made since started_at and dated before today, all with
  # no seen_at. Today's own brief never counts, so one already made today is never a reason to pause.
  def gone_unseen?(today = user.today)
    newest = user.daily_briefs.where(created_at: started_at.., on: ...today).order(on: :desc).limit(7).pluck(:seen_at)
    newest.size == 7 && newest.none?
  end

  # What a brief on that date is built from, copied so editing the plan never changes it (Trap 7): the sections, the
  # focus areas in order, and that weekday's row with its topics keyed by focus area.
  def copy_for(date)
    day = days.find_by!(wday: date.wday)

    { "sections" => sections, "focus_areas" => focus_areas.map { it.slice(:id, :kind, :name, :gives, :scriptures) },
      "day" => day.slice(:wday, :reading, :examples, :topics) }.as_json
  end

  def full?
    focus_areas.size >= DailyBrief::FocusArea::MAX
  end

  # The library entries Your plan offers as chips, and the dialog fills in from: not a role the plan already has by
  # name, nor a second quality or appreciation (docs/design/daily-brief.md, DailyBrief::FocusArea).
  def library_offers
    names, kinds = focus_areas.map(&:name), focus_areas.map(&:kind)
    DailyBrief::FocusArea::Library.all.reject { it.name.in?(names) || (it.kind != "role" && it.kind.in?(kinds)) }
  end

  # The focus areas with a column in Your week, Qualities first: every one but appreciation, which draws on the day's
  # reading (frame brief-plan.png).
  def topic_areas
    focus_areas.reject(&:appreciation?).partition(&:quality?).flatten
  end

  # A day's dialog has a box for every focus area (the story, #302): Your week's columns, then appreciation.
  def day_areas
    topic_areas + focus_areas.select(&:appreciation?)
  end

  # The starter's focus areas in order, then a row per weekday, each topic keyed by the id of the focus area it's for.
  def fill_from(starter)
    areas = starter.focus_areas.each_with_index.to_h do |entry, position|
      [ entry.key, focus_areas.create!(position:, **entry.attributes) ]
    end

    starter.days.each do |row|
      days.create!(wday: row.wday, reading: row.reading, examples: row.examples,
                   topics: row.topics.slice(*areas.keys).to_h { |key, topic| [ areas[key].id, topic ] })
    end
  end

  private
    # Today's brief is made and, for someone with the AI terms, has a writing of any status, so a run that stopped after
    # making the brief is finished by the next one, and a brief is never written twice by the job.
    def prepared?(date)
      brief = user.daily_briefs.find_by(on: date)
      brief.present? && (brief.writings.exists? || !user.accepted_ai_terms?)
    end

    # Minutes since midnight on the clock, so ready-by stays 5:00 AM on the day the clocks change.
    def minutes_into(time)
      time.hour * 60 + time.min
    end

    def sections_offered
      errors.add(:sections, "can only be #{SECTIONS.to_sentence(last_word_connector: " and ")}") unless (sections - SECTIONS).empty?
    end
end
