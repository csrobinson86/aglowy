class CreateNotificationSettings < ActiveRecord::Migration[8.1]
  # Which kinds also come by email or push, quiet hours, and the daily summary's cursor (docs/design/notifications.md,
  # Models and Delivery). A setting exists only once a person turns it on, so everything beyond the inbox starts off.
  def change
    create_table :notification_settings, id: :uuid do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.string :kind, null: false
      t.string :channel, null: false
      t.datetime :created_at, null: false

      t.index %i[ user_id kind channel ], unique: true
      t.check_constraint "kind IN ('weekly_preview', 'study_topic_needed', 'shared_with_you', 'invitation_unaccepted')", name: "notification_settings_kind_check"
      t.check_constraint "channel IN ('email', 'push')", name: "notification_settings_channel_check"
    end

    change_table :users, bulk: true do |t|
      # Wall-clock times in the person's own zone, on the half hour.
      t.time :quiet_hours_start, null: false, default: "21:00"
      t.time :quiet_hours_end, null: false, default: "07:00"
      # When the last daily summary was due. NULL until they first turn on a summary kind's email.
      t.datetime :summary_sent_through
      t.check_constraint "EXTRACT(MINUTE FROM quiet_hours_start) IN (0, 30) AND EXTRACT(SECOND FROM quiet_hours_start) = 0 AND " \
                         "EXTRACT(MINUTE FROM quiet_hours_end) IN (0, 30) AND EXTRACT(SECOND FROM quiet_hours_end) = 0", name: "users_quiet_hours_half_hour_check"
    end
  end
end
