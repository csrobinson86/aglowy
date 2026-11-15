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

  def schedule_family_study(topic: nil, notes: nil, links: [], files: [], **attributes)
    family_studies.build(attributes).tap { it.schedule(topic: topic, notes: notes, links: links, files: files) }
  end

  private
    def stored_blobs
      attachments = ActiveStorage::Attachment.where(record_type: FamilyStudy::Resource.polymorphic_name, name: "file", record_id: family_study_resources.select(:id))
      ActiveStorage::Blob.where(id: attachments.select(:blob_id))
    end
end
