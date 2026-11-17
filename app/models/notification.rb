# Something that needs or concerns one person, from one of their households (docs/design/notifications.md, Models).
# Made only through User#notify. Nothing personal is stored: what it says is worked out from its kind and subject each
# time it's shown, so a renamed person or household reads the new name.
class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :household
  belongs_to :subject, polymorphic: true
  belongs_to :actor, class_name: "User", optional: true
  has_one :reading, dependent: :delete
  # The database deletes them with it (on_delete: :cascade).
  has_many :deliveries, dependent: :delete_all

  # From households where the person is still an active member: leaving hides them, without deleting them (Trap 8).
  scope :visible, -> do
    memberships = Membership.arel_table
    where(Membership.active.where(memberships[:user_id].eq(arel_table[:user_id]).and(memberships[:household_id].eq(arel_table[:household_id]))).arel.exists)
  end
  scope :unread, -> { where.missing(:reading) }
  scope :not_emailed, -> { where.not(id: Delivery.email.select(:notification_id)) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :preloaded, -> { includes(:subject, :actor, :household, :reading) }
  # Kept for 90 days; their readings and deliveries go with them (on_delete: :cascade).
  scope :expired, -> { where(created_at: ...90.days.ago) }

  delegate :title, :body, :icon, :color, :email, :email_subject, :label, :target_path, to: :kind_definition

  # Deletes these, as a share ending or the purge does, and refreshes each person's counter once that's committed, so
  # an open page doesn't keep counting one that's gone. delete_all skips callbacks, so nothing else would.
  def self.withdraw
    user_ids = distinct.pluck(:user_id)
    delete_all
    ActiveRecord.after_all_transactions_commit { User.where(id: user_ids).find_each(&:broadcast_unread_notifications_count) }
  end

  # Opening it is the only way one is read (Trap 5). create_or_find_by! leans on the unique index, so two opens make one.
  def read
    return if read?

    self.reading = Reading.create_or_find_by!(notification: self)
    user.broadcast_unread_notifications_count
  end

  def read?
    reading.present?
  end

  def deliver_later
    Notification::DeliveryJob.perform_later(self)
  end

  # The email part of delivery (docs/design/notifications.md, Delivery): only while it's still the person's to see,
  # only a right-away kind they turned email on for, and never to a child. Inside quiet hours it comes back when they
  # end and checks everything again. Then it claims the email and sends only if the claim is its own. Push comes with
  # its own story.
  def deliver_now
    return unless user.notifications.visible.exists?(id) && emailed_right_away?

    if user.quiet_now?
      Notification::DeliveryJob.set(wait_until: user.quiet_hours_end_after(Time.current)).perform_later(self)
    elsif Delivery.claim(self, "email")
      Delivery.sending([ id ], "email") { NotificationMailer.notification(self).deliver_now }
    end
  end

  private
    def emailed_right_away?
      kind_definition.right_away? && user.emailable? && user.notification_settings.email.exists?(kind:)
    end

    def kind_definition
      @kind_definition ||= Kind.for(self)
    end
end
