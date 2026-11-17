# Something that needs or concerns one person, from one of their households (docs/design/notifications.md, Models).
# Made only through User#notify. Nothing personal is stored: what it says is worked out from its kind and subject each
# time it's shown, so a renamed person or household reads the new name.
class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :household
  belongs_to :subject, polymorphic: true
  belongs_to :actor, class_name: "User", optional: true
  has_one :reading, dependent: :delete

  # From households where the person is still an active member: leaving hides them, without deleting them (Trap 8).
  scope :visible, -> do
    memberships = Membership.arel_table
    where(Membership.active.where(memberships[:user_id].eq(arel_table[:user_id]).and(memberships[:household_id].eq(arel_table[:household_id]))).arel.exists)
  end
  scope :unread, -> { where.missing(:reading) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :preloaded, -> { includes(:subject, :actor, :household, :reading) }
  # Kept for 90 days; their readings and deliveries go with them (on_delete: :cascade).
  scope :expired, -> { where(created_at: ...90.days.ago) }

  delegate :title, :body, :icon, :color, :email, :target_path, to: :kind_definition

  # Opening it is the only way one is read (Trap 5). create_or_find_by! leans on the unique index, so two opens make one.
  def read
    return if read?

    self.reading = Reading.create_or_find_by!(notification: self)
    user.broadcast_unread_notifications_count
  end

  def read?
    reading.present?
  end

  # Sends nothing yet: email and push come in later NOTIFY-01 stories.
  def deliver_later
    Notification::DeliveryJob.perform_later(self)
  end

  private
    def kind_definition
      @kind_definition ||= Kind.for(self)
    end
end
