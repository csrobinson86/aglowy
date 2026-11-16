class User < ApplicationRecord
  has_one :identity, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :households, through: :memberships
  has_many :meeting_notes, dependent: :destroy
  # Personal goals only, by user_id. Family goals they set are the household's (set_by_id).
  has_many :goals, dependent: :destroy
  # Destroyed one by one, so their notes and taggings go too; before collections, whose studies the database would keep.
  has_many :personal_studies, dependent: :destroy
  has_many :collections, dependent: :delete_all
  has_many :chats, dependent: :destroy
  # The database deletes their taggings with them (on_delete: :cascade).
  has_many :tags, dependent: :delete_all
  has_many :family_study_drafts, class_name: "FamilyStudy::Draft", dependent: :delete_all
  has_many :ai_acceptances, class_name: "Ai::Acceptance", dependent: :delete_all
  # Deleting the person deletes the open invitations they sent (invited_by_id is not null).
  has_many :sent_invitations, class_name: "Invitation", foreign_key: :invited_by_id, inverse_of: :invited_by, dependent: :delete_all

  normalizes :name, with: -> { it.squish }
  # For personal reminders; a login-less child has none, and account settings can leave it unset.
  normalizes :time_zone, with: -> { it.presence }

  # How Aglowy looks for them, on every device (docs/design/app-shell.md, Theming and appearance).
  # validate: true makes an unknown value a validation error rather than an ArgumentError.
  enum :appearance, { auto: "auto", light: "light", dark: "dark" }, prefix: true, validate: true

  validates :name, presence: true
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }, allow_nil: true

  # "Invited by Daniel" (frame members.png).
  def first_name
    name.split.first
  end

  # A child's username-only login (docs/design/invitations.md, Child logins). Its random password is never shown,
  # so nobody can sign in until the child chooses one through a password link. Identity.new, not build_identity,
  # which would replace a login the person already has; the unique index on identities.user_id keeps it to one.
  # Two submissions at once both pass the checks in Ruby, so the loser gets an error on Username, not an exception.
  def give_login(username:)
    identity = Identity.new(user: self, username: username, password: SecureRandom.base58(32), confirmed_at: Time.current)
    identity.save
    identity
  rescue ActiveRecord::RecordNotUnique => conflict
    raise unless conflict.message.match?(/index_identities_on_(lower_username|user_id)/)

    if conflict.message.include?("index_identities_on_user_id")
      identity.errors.add(:username, "wasn't saved: #{first_name} already has a login")
    else
      identity.errors.add(:username, :taken)
    end

    identity
  end

  # Turned on AI drafts at the current version of the terms (docs/design/ai.md, First use).
  def accepted_ai_terms?
    ai_acceptances.exists?(version: Rails.configuration.x.ai.terms_version)
  end

  # The acceptance, or an unsaved one with an error when the box wasn't ticked. Accepting again finds the first one.
  def accept_ai_terms(understood:)
    ai_acceptances.create_or_find_by(version: Rails.configuration.x.ai.terms_version) { it.understood = understood }
  end

  def active_households
    households.merge(Membership.active)
  end

  # One of this person's active households, or nil: how account settings checks its return_to.
  def active_household(id)
    active_households.find_by(id: id)
  end

  # Children can't start a household (docs/design/invitations.md, Traps). Seats count active or not, so an adult
  # who left every household still can, and someone who only ever had child seats still can't. Someone with no
  # seats yet can. Read from the loaded seats, so the switcher's previews of unsaved people answer it too.
  def can_start_household?
    seats = memberships.to_a
    seats.none? || !seats.all?(&:child?)
  end

  # Finds this person's note for the meeting that week, or creates it with its parts in the same
  # transaction. The unique index on (user_id, kind, week_of) settles two starts at once.
  def start_meeting_note(kind:, week_of:)
    meeting_notes.create_or_find_by!(kind: kind, week_of: week_of, &:build_parts)
  end

  # Membership#deactivate calls this inside its transaction, so the shares end with the membership.
  def stop_sharing_meeting_notes_with(household)
    MeetingNote::Sharing.where(household: household, meeting_note: meeting_notes).delete_all
  end

  # Membership#deactivate calls this inside its transaction too, so personal goals stop being shared there as well.
  def stop_sharing_goals_with(household)
    Goal::Sharing.where(household: household, goal: goals).delete_all
  end

  # Membership#deactivate calls this under the household's lock, so a step naming only someone who left can
  # still be finished. Done steps keep their assignments and ticks as history (docs/design/goals.md,
  # "Leaving a household"). A person's tick on a named step always has an assignment beside it.
  def leave_open_goal_steps_in(household)
    named_steps = household.goal_steps.where(id: Goal::Step::Assignment.where(user: self).select(:step_id))
    open_steps = named_steps.includes(:assignments, :completions).reject(&:done?)

    Goal::Step::Completion.where(user: self, step: open_steps).delete_all
    Goal::Step::Assignment.where(user: self, step: open_steps).delete_all
  end

  # That week's Life and Ministry and Weekend notes, in that order. One not started yet is a new, unsaved note.
  def meeting_notes_for_week(week_of)
    started = meeting_notes.preloaded.where(week_of: week_of).index_by(&:kind)
    MeetingNote.kinds.keys.map { |kind| started[kind] || MeetingNote.new(kind: kind, week_of: week_of) }
  end
end
