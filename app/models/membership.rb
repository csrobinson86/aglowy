class Membership < ApplicationRecord
  belongs_to :household
  belongs_to :user
  # The database deletes it with the seat (on_delete: :cascade).
  has_one :study_ai_grant, dependent: :delete
  # The same.
  has_one :time_sharing, dependent: :delete

  enum :role, %i[ head adult child ].index_by(&:itself), default: :adult, validate: true

  scope :active, -> { where(active: true) }
  scope :preloaded, -> { includes(user: :identity) }
  scope :by_role, -> { in_order_of(:role, roles.keys).order(:created_at) }
  scope :by_household_name, -> { includes(:household).order("households.name") }
  scope :with_study_ai_grant, -> { where(id: Membership::StudyAiGrant.select(:membership_id)) }
  scope :sharing_times, -> { where(id: Membership::TimeSharing.select(:membership_id)) }

  def sole_head?
    head? && active? && household.memberships.active.head.where.not(id: id).none?
  end

  # This week's Monday, in the person's own time zone when they've set one, else the household's.
  def this_week
    Time.current.in_time_zone(user.time_zone.presence || household.time_zone).to_date.beginning_of_week(:monday)
  end

  # What Today's meeting offers, kind => week_of: the household's current or next meeting, or this week's two before
  # any times are set (docs/design/meeting-helper.md, The Today's meeting page).
  def todays_meetings
    if (meeting = household.current_or_next_meeting)
      { meeting.kind => meeting.week_of }
    else
      Household::MEETING_KINDS.index_with(this_week)
    end
  end

  # Start accepts only what the page could have offered (Trap 4). week_of is the ISO date the page posted.
  def todays_meeting?(kind:, week_of:)
    todays_meetings[kind]&.iso8601 == week_of
  end

  # Leaving ends the person's meeting-note and goal shares here for good, so rejoining never brings them back
  # (docs/design/meeting-notes.md, "Leaving ends a share for good"), takes them off the steps not yet
  # done in the household's goals (docs/design/goals.md, "Leaving a household"), and ends a child's study AI grant
  # (docs/design/personal-study.md, Children).
  def deactivate
    without_losing_last_head(leaves_headship: true) do
      update(active: false).tap do |deactivated|
        if deactivated
          user.stop_sharing_meeting_notes_with(household)
          user.stop_sharing_goals_with(household)
          user.leave_open_goal_steps_in(household)
          revoke_study_ai
        end
      end
    end
  end

  def change_role(role)
    without_losing_last_head(leaves_headship: role.to_s != "head") do
      update(role: role).tap { |changed| revoke_study_ai if changed && !child? }
    end
  end

  # Personal study with AI for this child, from Settings → Children (docs/design/personal-study.md, Children). The
  # grant, or an unsaved one with the reason when the seat isn't an active child's with a login.
  # Turning it on twice finds the first grant: the unique index settles two heads at once. It takes the household
  # lock and reads the seat again, as leaving and role changes do, so a copy loaded before the child left can't
  # leave a grant behind for rejoining to bring back.
  def grant_study_ai(by:)
    transaction do
      household.lock!
      reload
      Membership::StudyAiGrant.create_with(granted_by: by).create_or_find_by(membership: self)
    end.tap { reset_study_ai_grant }
  end

  # Stops new questions and ends heads' view; the child keeps their studies.
  def revoke_study_ai
    Membership::StudyAiGrant.where(membership: self).delete_all
    reset_study_ai_grant
  end

  def study_ai_grant?
    study_ai_grant.present?
  end

  # The person's own times on this household's calendar (docs/design/calendar.md, Membership::TimeSharing). Sharing twice
  # finds the first row: the unique index settles a double save.
  def share_times
    Membership::TimeSharing.create_or_find_by!(membership: self).tap { reset_time_sharing }
  end

  def stop_sharing_times
    Membership::TimeSharing.where(membership: self).delete_all
    reset_time_sharing
  end

  def shares_times?
    time_sharing.present?
  end

  private

  # Locks the household so two heads can't demote each other at the same moment (gotcha 5), then reads this
  # seat again: every change to a seat takes the same lock, so a copy loaded before a promotion can't slip past.
  def without_losing_last_head(leaves_headship:)
    transaction do
      household.lock!
      reload

      if leaves_headship && sole_head?
        errors.add(:base, "A household needs at least one active head")
        false
      else
        yield
      end
    end
  end
end
