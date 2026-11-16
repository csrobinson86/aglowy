# A family goal belongs to a household, a personal goal to one person; exactly one is set, and the
# database checks it (docs/design/goals.md, gotcha 9). Completing and archiving are records, so a
# finished goal is kept to look back on.
class Goal < ApplicationRecord
  include Shareable, Taggable

  belongs_to :household, optional: true
  belongs_to :user, optional: true
  belongs_to :set_by, class_name: "User"
  has_one :completion, dependent: :delete
  has_one :archival, dependent: :delete
  has_many :steps, -> { order(:position) }, dependent: :delete_all, inverse_of: :goal

  enum :kind, %w[ milestone ].index_by(&:itself), default: :milestone, validate: true

  encrypts :title, :body

  validates :title, :target_on, presence: true

  # The family goals list's tabs (docs/design/goals.md, Pages).
  STATUSES = %w[ active completed archived ].freeze

  # Titles are encrypted, so lists sort by dates only.
  scope :active, -> { where.missing(:completion, :archival).order(:target_on) }
  scope :completed, -> { joins(:completion).where.missing(:archival).order(Goal::Completion.arel_table[:created_at].desc) }
  scope :archived, -> { joins(:archival).order(Goal::Archival.arel_table[:created_at].desc) }
  scope :preloaded, -> { includes(:user, :sharings, :shared_households, completion: :completed_by, archival: :archived_by, steps: [ { assignments: :user }, :completions, { family_study: :first_session } ], household: { active_memberships: :user }) }

  # The goals a person works on from this household: its family goals and their own personal goals.
  # Every change to a goal finds it here, so a goal someone shared with them is a 404 to change.
  scope :family_or_own, ->(membership) { where(household_id: membership.household_id).or(where(user_id: membership.user_id)) }

  # The goals a person can open from this household: those, and personal goals others shared there,
  # read-only (docs/design/goals.md, "Loading a goal").
  scope :reachable_from, ->(membership) { family_or_own(membership).or(where(id: shared_with(membership.household).select(:id))) }

  # A tab's goals; anything that isn't a status is Active.
  scope :with_status, ->(status) do
    case status
    when "completed" then completed
    when "archived" then archived
    else active
    end
  end

  def family?
    household_id.present?
  end

  def personal?
    user_id.present?
  end

  # Family goals are the household's, so only a personal goal takes its owner's tags (docs/design/tags.md, Traps).
  def taggable_by?(user)
    personal? && super
  end

  # Dates on a family goal read in its household's time zone. A personal goal is the same in every household,
  # so its dates read in its owner's, or the app's when they haven't chosen one.
  def time_zone
    family? ? household.time_zone : user.time_zone || Time.zone.name
  end

  def completed?
    completion.present?
  end

  def archived?
    archival.present?
  end

  def progress
    Progress.new(self)
  end

  # Who a step can be for: the household's active members, from Goal.preloaded. A personal goal's steps name no one.
  def assignable_users
    family? ? household.active_memberships.map(&:user) : []
  end

  # Neither completed nor archived; only an open goal takes new steps or ticks.
  def open?
    !completed? && !archived?
  end

  # Each lifecycle write is a no-op when the goal is already there, so a stale page's button does nothing.
  def complete(by:)
    under_lock { create_completion!(completed_by: by) if open? }
  end

  # Assigning nil deletes the completion (dependent: :delete). An archived goal is restored first:
  # reopening it underneath would change what Restore brings back.
  def reopen
    under_lock { self.completion = nil if completed? && !archived? }
  end

  def archive(by:)
    under_lock { create_archival!(archived_by: by) unless archived? }
  end

  # Assigning nil deletes the archival. A completed goal that's restored goes back to Completed.
  def restore
    under_lock { self.archival = nil if archived? }
  end

  # Deleting is deliberate, so it wins over an edit saved since the goal was loaded: the row lock rereads
  # lock_version, so destroy! can't raise StaleObjectError, and an edit saved at the same moment waits for it.
  # A family goal takes the household lock first, like its other writes, so a step or tick waits for it too.
  # A goal someone else just deleted is RecordNotFound, a 404.
  def delete_for_good
    transaction do
      household.lock! if family?
      with_lock { destroy! }
    end
  end

  # New steps go last. The assignees are checked as active members behind the lock, like Step#reassign.
  def add_step(title:, due_on: nil, assignees: [])
    under_lock do
      require_open!
      steps.create!(title: title, due_on: due_on, position: steps.maximum(:position).to_i + 1) do |step|
        assignees.uniq.each { step.assignments.build(user: it) }
      end
    end
  end

  # One lock for every write: the household's row for a family goal (the lock Membership#deactivate
  # takes), the goal's own row for a personal one. The state is reread behind the lock, so two people
  # pressing the same button at once write once (docs/design/goals.md, "One lock for every write").
  # Steps take it too, for adding, reassigning and ticking. A goal deleted before the lock was taken is
  # RecordNotFound, a 404 (lock! finds that out for a personal goal).
  def under_lock
    transaction do
      family? ? lock_household_of_existing_goal : lock!
      reload_completion
      reload_archival
      yield
    end
  end

  # Inside under_lock, so the state it checks was reread behind the lock.
  def require_open!
    unless open?
      errors.add(:base, "This goal is finished, so it takes no new steps or ticks")
      raise ActiveRecord::RecordInvalid, self
    end
  end

  private
    def lock_household_of_existing_goal
      household.lock!
      raise ActiveRecord::RecordNotFound unless Goal.exists?(id)
    end
end
