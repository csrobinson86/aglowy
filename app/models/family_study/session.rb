class FamilyStudy::Session < ApplicationRecord
  belongs_to :family_study
  belongs_to :conductor, class_name: "User", optional: true

  # Cancelled sessions included, for lists that show them struck through (scheduling rule 6).
  scope :ahead, -> { where(scheduled_at: Time.current..).order(:scheduled_at) }
  scope :upcoming, -> { ahead.where(canceled_at: nil) }
  scope :preloaded, -> { includes(family_study: :household) }

  validates :recurrence_at, :scheduled_at, presence: true
  validates :recurrence_at, uniqueness: { scope: :family_study_id }

  def canceled?
    canceled_at?
  end

  # Shown in the household's zone, never the server's or the browser's (gotcha 14).
  def local_scheduled_at
    scheduled_at.in_time_zone(family_study.household.time_zone)
  end

  # A session's end is its study's duration after it starts.
  def local_ends_at
    local_scheduled_at + family_study.duration_minutes.minutes
  end
end
