# A family goal belongs to a household, a personal goal to one person; exactly one is set, and the
# database checks it (docs/design/goals.md, gotcha 9). Completing and archiving are records, so a
# finished goal is kept to look back on.
class Goal < ApplicationRecord
  belongs_to :household, optional: true
  belongs_to :user, optional: true
  belongs_to :set_by, class_name: "User"
  has_one :completion, dependent: :delete
  has_one :archival, dependent: :delete

  enum :kind, %w[ milestone ].index_by(&:itself), default: :milestone, validate: true

  encrypts :title, :body

  validates :title, :target_on, presence: true

  # Titles are encrypted, so lists sort by dates only.
  scope :active, -> { where.missing(:completion, :archival).order(:target_on) }
  scope :completed, -> { joins(:completion).where.missing(:archival).order(Goal::Completion.arel_table[:created_at].desc) }
  scope :archived, -> { joins(:archival).order(Goal::Archival.arel_table[:created_at].desc) }

  def family?
    household_id.present?
  end

  def personal?
    user_id.present?
  end

  def completed?
    completion.present?
  end

  def archived?
    archival.present?
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

  private
    # One lock for every write: the household's row for a family goal (the lock Membership#deactivate
    # takes), the goal's own row for a personal one. The state is reread behind the lock, so two people
    # pressing the same button at once write once (docs/design/goals.md, "One lock for every write").
    def under_lock
      transaction do
        family? ? household.lock! : lock!
        reload_completion
        reload_archival
        yield
      end
    end
end
