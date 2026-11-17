class CreateNotifications < ActiveRecord::Migration[8.1]
  # The inbox, what's been read, and each channel's delivery claim (docs/design/notifications.md, Models). Nothing personal
  # is stored: the wording is worked out from the kind and the subject when it's shown. Readings and deliveries go with
  # their notification, so the 90-day purge takes them too.
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.references :household, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.string :kind, null: false
      t.references :subject, null: false, polymorphic: true, type: :uuid
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }, type: :uuid
      t.jsonb :data, null: false, default: {}
      t.string :dedupe_key, null: false
      t.datetime :created_at, null: false

      t.index %i[ user_id dedupe_key ], unique: true
      t.index :created_at
      t.check_constraint "kind IN ('weekly_preview', 'study_topic_needed', 'shared_with_you', 'invitation_unaccepted')", name: "notifications_kind_check"
    end

    create_table :notification_readings, id: :uuid do |t|
      t.references :notification, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: { unique: true }
      t.datetime :created_at, null: false
    end

    create_table :notification_deliveries, id: :uuid do |t|
      t.references :notification, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.string :channel, null: false
      t.datetime :created_at, null: false

      t.index %i[ notification_id channel ], unique: true
      t.check_constraint "channel IN ('email', 'push')", name: "notification_deliveries_channel_check"
    end
  end
end
