class User < ApplicationRecord
  include Avatarable, Notifiable, StudyGuidePreparable

  has_one :identity, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :households, through: :memberships
  has_many :meeting_notes, dependent: :destroy
  # Destroyed one by one, so their encrypted preparation goes too.
  has_many :meeting_parts, dependent: :destroy
  # Personal goals only, by user_id. Family goals they set are the household's (set_by_id).
  has_many :goals, dependent: :destroy
  # Before their studies and notes, which would otherwise nullify each one first.
  has_many :bookmarks, dependent: :delete_all
  # The same; the database deletes their done marks with them.
  has_many :personal_times, dependent: :delete_all
  # Their private phone calendar link (docs/design/calendar.md, CalendarFeed).
  has_one :calendar_feed, dependent: :delete
  # Destroyed one by one, so their notes and taggings go too; before collections, whose studies the database would keep.
  has_many :personal_studies, dependent: :destroy
  # The same, for their bodies and taggings.
  has_many :personal_notes, dependent: :destroy
  has_many :collections, dependent: :delete_all
  has_many :chats, dependent: :destroy
  # The database deletes their taggings with them (on_delete: :cascade).
  has_many :tags, dependent: :delete_all
  has_many :family_study_drafts, class_name: "FamilyStudy::Draft", dependent: :delete_all
  has_many :ai_acceptances, class_name: "Ai::Acceptance", dependent: :delete_all
  has_many :ai_uses, class_name: "Ai::Use", dependent: :delete_all
  has_one :daily_brief_plan, class_name: "DailyBrief::Plan", dependent: :destroy
  has_many :daily_briefs, dependent: :destroy
  has_many :daily_brief_writings, through: :daily_briefs, source: :writings
  # Their study guide setting, while it's on (docs/design/study-guide.md, Models).
  has_one :weekly_study_guide, dependent: :delete
  # Deleting the person deletes the open invitations they sent (invited_by_id is not null).
  has_many :sent_invitations, class_name: "Invitation", foreign_key: :invited_by_id, inverse_of: :invited_by, dependent: :delete_all

  normalizes :name, with: -> { it.squish }
  # For personal reminders; a login-less child has none, and account settings can leave it unset.
  normalizes :time_zone, with: -> { it.presence }

  # How Aglowy looks for them, on every device (docs/design/app-shell.md, Theming and appearance).
  # validate: true makes an unknown value a validation error rather than an ArgumentError.
  enum :appearance, { auto: "auto", light: "light", dark: "dark" }, prefix: true, validate: true

  # The people for whom it's now that hour in limit_time_zone's zone: their own, else their oldest active membership's
  # household's, else UTC. The hourly study guide job asks for theirs (docs/design/study-guide.md, The weekly job).
  scope :at_local_hour, ->(hour, now: Time.current) do
    zones = ActiveSupport::TimeZone.all.map { now.in_time_zone(it) }.select { it.hour == hour }.map { it.time_zone.name }
    household_zone = Household.joins(:memberships).merge(Membership.active).where(Membership.arel_table[:user_id].eq(arel_table[:id]))
      .order("memberships.created_at", "memberships.id").limit(1).select(:time_zone)
    where(Arel::Nodes::NamedFunction.new("COALESCE", [ arel_table[:time_zone], household_zone.arel, Arel::Nodes.build_quoted("UTC") ]).in(zones))
  end

  validates :name, presence: true
  # The database checks it too (users_avatar_color_check); this gives a refused color a message.
  validates :avatar_color, inclusion: { in: Avatar::Palette::COLORS }
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }, allow_nil: true
  # Their times are in it, so it can't go blank under them (docs/design/calendar.md, The person's own zone).
  validates :time_zone, presence: { message: "can't be blank while you have times on the calendar" }, if: -> { time_zone.nil? && personal_times.exists? }

  # Settings → Profile's "Color for your initial" (docs/design/avatars.md, User).
  def change_avatar_color(color)
    update(avatar_color: color)
  end

  # Their avatar's letter: the first of their name as a reader sees it, accent and all, in capitals, so "émile" is É
  # (docs/design/avatars.md, What an avatar is).
  def initial
    name.grapheme_clusters.first.upcase
  end

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

  # Head or adult in any active household, or a child with a head's grant in any of them: personal study is the
  # person's, not one household's (docs/design/personal-study.md, Who can do what).
  def may_ask_study_ai?
    memberships.active.merge(Membership.where(role: %w[ head adult ]).or(Membership.child.with_study_ai_grant)).exists?
  end

  # A head somewhere can read their personal studies, so their Personal study page tells them.
  def personal_study_read_by_heads?
    memberships.active.child.with_study_ai_grant.exists?
  end

  # Where midnight is for their per-person AI limits: their own time zone, else their oldest active membership's
  # household's, else UTC. Never the household of the current request, so switching households can't restart the day.
  def limit_time_zone
    time_zone || memberships.active.order(:created_at, :id).first&.household&.time_zone || "UTC"
  end

  # Today's personal study questions left, counted from their uses, never their questions, so deleting a study can't
  # give any back (docs/design/personal-study.md, Traps).
  def study_questions_left_today
    used = ai_uses.personal_study.since(Time.current.in_time_zone(limit_time_zone).beginning_of_day).count
    [ PersonalStudy::Question.daily_limit - used, 0 ].max
  end

  # Head or adult in any active household. Meeting parts are the person's, not one household's, and children never get
  # AI help with them (docs/design/meeting-parts.md, Who can do what).
  def may_prepare_parts_with_ai?
    head_or_adult_somewhere?
  end

  # Head or adult in any active household. The daily brief is the person's, not one household's, and children have none
  # (docs/design/daily-brief.md, Who can do what).
  def may_have_daily_brief?
    head_or_adult_somewhere?
  end

  # Head or adult in any active household. The study guide is the person's, not one household's, and children have none
  # (docs/design/study-guide.md, Who can do what).
  def may_have_study_guide?
    head_or_adult_somewhere?
  end

  def study_guide_on?
    weekly_study_guide.present?
  end

  # False, saving nothing, without accepted AI terms. create_or_find_by! on the unique index makes one row however many
  # times it's turned on (docs/design/study-guide.md, The Settings section).
  def turn_on_study_guide
    return false unless accepted_ai_terms?

    User::WeeklyStudyGuide.create_or_find_by!(user: self).tap { reset_weekly_study_guide }
  end

  def turn_off_study_guide
    User::WeeklyStudyGuide.where(user: self).delete_all
    reset_weekly_study_guide
  end

  # Daily brief writings left today, counted like personal study's questions (docs/design/daily-brief.md, The purpose).
  def daily_brief_writings_left_today
    used = ai_uses.daily_brief.since(Time.current.in_time_zone(limit_time_zone).beginning_of_day).count
    [ DailyBrief::Writing.daily_limit - used, 0 ].max
  end

  # Today's meeting part requests left, counted from their uses, so deleting a draft or a part can't give any back.
  def part_drafts_left_today
    used = ai_uses.meeting_part.since(Time.current.in_time_zone(limit_time_zone).beginning_of_day).count
    [ MeetingPart::Draft.daily_limit - used, 0 ].max
  end

  # The zone their own times are in, and the phone feed: their profile's, else their first active household's by name
  # then id, else UTC (docs/design/calendar.md, The person's own zone).
  def calendar_time_zone
    time_zone || active_households.order(:name, :id).first&.time_zone || "UTC"
  end

  # Today in their own zone, for what's coming up in their meeting parts (docs/design/meeting-parts.md, MeetingPart).
  def today
    Time.current.in_time_zone(calendar_time_zone).to_date
  end

  # Adding their first time with no profile zone saves the household's, so renaming or leaving a household never moves
  # a time. PersonalTime#plan calls it in the time's transaction.
  def settle_time_zone(household)
    update!(time_zone: household.time_zone) if time_zone.nil?
  end

  def active_households
    households.merge(Membership.active)
  end

  # The active households whose calendars show their times, by name (docs/design/calendar.md, The page).
  def households_seeing_times
    active_households.merge(Membership.sharing_times).order(:name, :id)
  end

  # Settings → Calendar: shares their times with the active households ticked and stops with the rest, in one
  # transaction. Any other household is ignored. The lock makes two saves at once take turns, so the later one wins
  # rather than leaving both selections shared.
  def share_times_only_with(household_ids)
    with_lock do
      memberships.active.each { it.household_id.in?(household_ids) ? it.share_times : it.stop_sharing_times }
    end
  end

  # Made the first time Settings → Calendar shows it. The unique index on user_id settles two first views at once.
  def ensure_calendar_feed
    calendar_feed || CalendarFeed.create_or_find_by!(user: self)
  end

  # One of this person's active households, or nil: how AiAcceptancesController checks its return_to.
  def active_household(id)
    active_households.find_by(id: id)
  end

  # Children can't start a household (docs/design/invitations.md, Traps). Seats count active or not, so an adult
  # who left every household still can, and someone who only ever had child seats still can't. Someone with no
  # seats yet can. Read from the loaded seats, so it answers for unsaved people too.
  def can_start_household?
    seats = memberships.to_a
    seats.none? || !seats.all?(&:child?)
  end

  # Their bookmark for a page or a scripture, or nil (docs/design/bookmarks.md, User). A URL is normalized as saving
  # would, so one Bookmark refuses finds nothing.
  def bookmark_for(url: nil, scripture: nil)
    key = url ? { url: Bookmark.normalize_value_for(:url, url) } : { scripture: }
    bookmarks.find_by(key) if key.values.first
  end

  # Everything they've bookmarked, in one query, for a page with many bookmark buttons to pass to each: each key (a
  # normalized URL or a scripture id) with its bookmark's id, so a filled button can remove it. include? reads it like
  # a Set.
  def bookmarked
    bookmarks.pluck(:url, :scripture, :id).to_h { |url, scripture, id| [ url || scripture, id ] }
  end

  # Finds or saves their bookmark for a page or a scripture the source showed them. A page's title comes from the
  # source's own sources, never from a form, and a page that isn't among them is refused, as is a scripture that isn't
  # in its scripture_references: a bookmark only ever holds a link Aglowy showed (docs/design/bookmarks.md, Traps). The
  # unique index settles two saves at once.
  def bookmark(source:, url: nil, scripture: nil)
    return bookmark_scripture(scripture, source:) if scripture

    url = Bookmark.normalize_value_for(:url, url)
    # Only a study has pages: a note's links are scriptures, so a page posted with a note is refused.
    page = source.try(:sources)&.find { Bookmark.normalize_value_for(:url, it["url"]) == url } if url

    if page
      bookmarks.create_or_find_by(url:) do |bookmark|
        bookmark.title = page["title"].presence&.truncate(Bookmark::TITLE_MAX)
        bookmark.source = source
      end
    else
      bookmarks.new(url:, source:).tap { it.errors.add(:url, "isn't one of the pages in this study") }
    end
  end

  # Finds this person's note for the meeting that week, or creates it with its parts in the same
  # transaction. The unique index on (user_id, kind, week_of) settles two starts at once.
  def start_meeting_note(kind:, week_of:)
    meeting_notes.create_or_find_by!(kind: kind, week_of: week_of, &:build_parts)
  end

  # Membership#deactivate calls this inside its transaction, so the shares end with the membership, and their
  # "shared with you" notifications there with them.
  def stop_sharing_meeting_notes_with(household)
    MeetingNote::Sharing.where(household: household, meeting_note: meeting_notes).delete_all
    Notification.where(household: household, subject_type: "MeetingNote", subject_id: meeting_notes.select(:id)).withdraw
  end

  # Membership#deactivate calls this inside its transaction too, so personal goals stop being shared there as well.
  def stop_sharing_goals_with(household)
    Goal::Sharing.where(household: household, goal: goals).delete_all
    Notification.where(household: household, subject_type: "Goal", subject_id: goals.select(:id)).withdraw
  end

  # And meeting parts, so a part is private again after leaving, even on rejoining.
  def stop_sharing_meeting_parts_with(household)
    MeetingPart::Sharing.where(household: household, meeting_part: meeting_parts).delete_all
    Notification.where(household: household, subject_type: "MeetingPart", subject_id: meeting_parts.select(:id)).withdraw
  end

  # And daily briefs, so today's thought is private again after leaving. They make no notifications to withdraw.
  def stop_sharing_daily_briefs_with(household)
    DailyBrief::Sharing.where(household: household, daily_brief: daily_briefs).delete_all
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

  private
    def head_or_adult_somewhere?
      memberships.active.where(role: %w[ head adult ]).exists?
    end

    def bookmark_scripture(scripture, source:)
      id = Bookmark.normalize_value_for(:scripture, scripture)

      if source.scripture_references.any? { it.id == id }
        bookmarks.create_or_find_by(scripture: id) { it.source = source }
      else
        bookmarks.new(scripture:, source:).tap { it.errors.add(:scripture, "isn't one of the scriptures in this study or note") }
      end
    end
end
