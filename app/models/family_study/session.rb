class FamilyStudy::Session < ApplicationRecord
  belongs_to :family_study
  belongs_to :conductor, class_name: "User", optional: true

  scope :upcoming, -> { where(canceled_at: nil, scheduled_at: Time.current..).order(:scheduled_at) }
  scope :preloaded, -> { includes(:family_study) }

  validates :recurrence_at, :scheduled_at, presence: true
  validates :recurrence_at, uniqueness: { scope: :family_study_id }
end
