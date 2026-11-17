class FamilyStudy::Session < ApplicationRecord
  include ScriptureLinkable

  belongs_to :family_study
  belongs_to :conductor, class_name: "User", optional: true
  has_many :resources, -> { order(:position) }, dependent: :destroy
  # Its "no topic yet" notifications (docs/design/notifications.md, Models).
  has_many :notifications, as: :subject, dependent: :delete_all

  has_rich_text :notes, encrypted: true
  scripture_linkable :notes

  # Cancelled sessions included, for lists that show them struck through (scheduling rule 6).
  scope :ahead, -> { where(scheduled_at: Time.current..).order(:scheduled_at) }
  scope :upcoming, -> { ahead.where(canceled_at: nil) }
  scope :preloaded, -> { includes(family_study: :household) }
  scope :without_topic, -> { where(topic: [ nil, "" ]) }

  validates :recurrence_at, :scheduled_at, presence: true
  validates :recurrence_at, uniqueness: { scope: :family_study_id }

  def canceled?
    canceled_at?
  end

  # Moves this session only, to a date and time in the household's zone, and detaches it from the
  # schedule (scheduling rule 7). recurrence_at stays, so the generator never brings the slot back (gotcha 21).
  # Unchanged local fields keep the instant: rebuilding a repeated fall-back hour would pick the first one.
  # Behind the household's lock, then reread, so the zone and the time it starts from are the ones a time zone change
  # left, and the change can't overwrite this move (Household#update_settings).
  def reschedule(on:, at:)
    transaction do
      family_study.household.lock!
      lock!
      local = local_scheduled_at
      next if [ local.to_date, local.hour, local.min ] == [ on, at.hour, at.min ]

      update!(scheduled_at: household_zone.local(on.year, on.month, on.day, at.hour, at.min), detached_at: Time.current)
    end
  end

  # Skips this session only; the row stays, so the generator never recreates it (scheduling rule 6).
  # Its "no topic yet" notifications go too, since there's nothing left to choose a topic for.
  def cancel
    return if canceled?

    transaction do
      update!(canceled_at: Time.current)
      notifications.withdraw
    end
  end

  # "Tuesday's family study has no topic yet", to each of the household's heads, once per session (Trap 1). Reread under
  # its lock, held until the notifications are in, so a cancel either comes first and leaves nothing to ask, or waits
  # and withdraws them.
  def ask_heads_for_topic
    transaction do
      lock!
      next if canceled?

      household = family_study.household
      household.memberships.active.head.includes(:user).each do |membership|
        membership.user.notify(kind: "study_topic_needed", household:, subject: self, dedupe_key: "study_topic_needed:#{id}")
      end
    end
  end

  def restore
    update!(canceled_at: nil)
  end

  # One file resource per uploaded file (signed blob ids), titled with its name. An id that can't be
  # found is dropped. If one file is refused, none are added; the refused one carries its errors.
  def add_files(files)
    blobs = files.uniq.filter_map { ActiveStorage::Blob.find_signed(it) }
    new_resources = blobs.map { resources.build(kind: :file, file: it) }

    if new_resources.all?(&:valid?)
      # A savepoint of its own, so the rollback undoes the batch even inside a caller's transaction.
      transaction(requires_new: true) do
        # Saved one at a time behind a lock on the household, so each file is judged against the
        # quota with the ones before it, and two uploads at once can't both take the last of it.
        family_study.household.lock!
        raise ActiveRecord::Rollback unless new_resources.all?(&:save)
      end
    end
    new_resources
  end

  # Shown in the household's zone, never the server's or the browser's (gotcha 14).
  def local_scheduled_at
    scheduled_at.in_time_zone(household_zone)
  end

  # A session's end is its study's duration after it starts.
  def local_ends_at
    local_scheduled_at + family_study.duration_minutes.minutes
  end

  private
    def household_zone
      ActiveSupport::TimeZone[family_study.household.time_zone]
    end
end
