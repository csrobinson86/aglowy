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
  # DailyBrief::Pause). Stopping a writing still in progress joins this when writings arrive.
  def pause(reason:)
    user.with_lock { reload_pausing || create_pausing!(reason:) }
  end

  def paused?
    pausing.present?
  end

  # Starts a paused plan again from now, so the briefs that went unseen before the pause can't pause it again, and the
  # job's next brief is tomorrow morning's (Trap 13). A plan that isn't paused keeps its started_at.
  def resume
    user.with_lock do
      if reload_pausing
        pausing.destroy!
        reset_pausing
        update!(started_at: Time.current)
      end
    end
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
    def sections_offered
      errors.add(:sections, "can only be #{SECTIONS.to_sentence(last_word_connector: " and ")}") unless (sections - SECTIONS).empty?
    end
end
