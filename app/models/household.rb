class Household < ApplicationRecord
  # The roles a head can give someone they add; headship is never handed out here.
  MEMBER_ROLES = %w[ adult child ].freeze

  # Never dependent: :destroy on users: a shared-custody child belongs to other households too.
  has_many :memberships, dependent: :destroy
  has_many :active_memberships, -> { active.by_role }, class_name: "Membership", inverse_of: :household
  has_many :users, through: :memberships
  has_many :family_studies, dependent: :destroy
  has_many :family_study_sessions, through: :family_studies, source: :sessions, class_name: "FamilyStudy::Session"
  has_many :family_study_resources, through: :family_study_sessions, source: :resources, class_name: "FamilyStudy::Resource"
  has_many :goals, dependent: :destroy
  has_many :invitations, dependent: :delete_all
  has_many :goal_steps, through: :goals, source: :steps, class_name: "Goal::Step"

  validates :name, presence: true
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }

  def self.create_with_head(household:, head:)
    transaction do
      create!(household).tap { it.memberships.create!(user: head, role: :head) }
    end
  end

  def add_member(name:, role:)
    raise ArgumentError, "add_member adds adults or children, not heads" unless role.to_s.in?(MEMBER_ROLES)

    transaction do
      memberships.create!(user: User.create!(name: name), role: role)
    end
  end

  # The household's files share one quota; links don't count (docs/design/family-studies.md, Files).
  # One SUM over the blobs attached to its file resources, never loading them.
  def storage_used
    stored_blobs.sum(:byte_size)
  end

  # What attaching the blobs would add: one the household already stores counts once, as storage_used counts it.
  def storage_added_by(blobs)
    stored_ids = stored_blobs.where(id: blobs.filter_map(&:id)).pluck(:id)
    blobs.uniq.reject { it.id.in?(stored_ids) }.sum(&:byte_size)
  end

  def storage_quota
    Rails.configuration.x.storage.household_quota
  end

  def storage_nearly_full?
    storage_used >= storage_quota * Rails.configuration.x.storage.warning_ratio
  end

  def storage_full?
    storage_used >= storage_quota
  end

  def fits_in_storage?(byte_size)
    storage_used + byte_size <= storage_quota
  end

  # Rounded down, so the warning never says 100% while there's still room.
  def storage_percent_used
    storage_used * 100 / storage_quota
  end

  def storage_quota_in_words
    ActiveSupport::NumberHelper.number_to_human_size(storage_quota)
  end

  def storage_full_message
    "Your household has used its #{storage_quota_in_words} of file storage. Remove some files to add more."
  end

  # The settings page's name and time zone, saved together behind the household's lock. A new zone keeps every
  # study ahead at the same local time (docs/design/invitations.md, Household settings; gotcha 14).
  def update_settings(attributes)
    transaction do
      lock!
      assign_attributes(attributes)
      next false unless valid?

      keep_sessions_at_local_time(from: time_zone_was) if time_zone_changed?
      save!
    end
  rescue ActiveRecord::RecordNotUnique
    # Only zones a day apart can do this: a daily study's session lands on the slot of one that's over and keeps it.
    errors.add(:time_zone, "can't be used: it's a day from the current zone, so a daily study would have two sessions in one slot")
    false
  end

  def change_time_zone(zone)
    update_settings(time_zone: zone)
  end

  def schedule_family_study(topic: nil, notes: nil, links: [], files: [], **attributes)
    family_studies.build(attributes).tap { it.schedule(topic: topic, notes: notes, links: links, files: files) }
  end

  private
    # Each session ahead is rebuilt from its local date and time in the old zone, never shifted by an offset, so a
    # session on the other side of a DST change keeps its time too. recurrence_at moves with it, and so does the slot of
    # any session the generator could build again, which starts from today: then every slot it builds in the new zone
    # is taken (gotcha 21). Past sessions keep their time, even when their slot follows the zone.
    # A slot is rebuilt from its date and the study's time, not its stored time: a study at 2:30 AM has its spring-forward
    # slot at 3:30, which in a zone without that gap the generator builds at 2:30.
    def keep_sessions_at_local_time(from:)
      old_zone, new_zone, now = ActiveSupport::TimeZone[from], ActiveSupport::TimeZone[time_zone], Time.current
      same_local_time = ->(time) { time.in_time_zone(old_zone).then { new_zone.local(it.year, it.month, it.day, it.hour, it.min) } }
      # Zones run at most 14 hours ahead of UTC, so a slot dated today anywhere starts after yesterday began.
      sessions = family_study_sessions.where(scheduled_at: now..).or(family_study_sessions.where(recurrence_at: Date.yesterday.beginning_of_day..))

      moves = sessions.includes(:family_study).filter_map do |session|
        moved, slot_date = {}, session.recurrence_at.in_time_zone(old_zone).to_date
        moved[:scheduled_at] = same_local_time.(session.scheduled_at) if session.scheduled_at >= now
        moved[:recurrence_at] = session.family_study.session_time_on(slot_date, zone: new_zone) if moved.any? || slot_date >= Date.current
        [ session, moved ] if moved.any?
      end

      # Between zones a day apart, a daily study's slot moves onto the next one's, so that one has to move first:
      # the latest first when slots move later, the earliest first when they move earlier.
      moves.sort_by { |session, moved| moved[:recurrence_at] > session.recurrence_at ? -session.recurrence_at.to_f : session.recurrence_at.to_f }
        .each { |session, moved| session.update_columns(moved.merge(updated_at: now)) }
    end

    def stored_blobs
      attachments = ActiveStorage::Attachment.where(record_type: FamilyStudy::Resource.polymorphic_name, name: "file", record_id: family_study_resources.select(:id))
      ActiveStorage::Blob.where(id: attachments.select(:blob_id))
    end
end
