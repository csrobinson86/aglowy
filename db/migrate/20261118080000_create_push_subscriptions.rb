class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  # A browser or phone a person turned push on for (docs/design/notifications.md, PushSubscription). The endpoint is
  # encrypted deterministically, so the unique index still holds one row per browser.
  def change
    create_table :push_subscriptions, id: :uuid do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.string :endpoint, null: false, index: { unique: true }
      t.string :p256dh_key, null: false
      t.string :auth_key, null: false
      t.string :label, null: false
      t.datetime :last_used_at
      t.datetime :created_at, null: false

      t.check_constraint "char_length(label) <= 80", name: "push_subscriptions_label_length_check"
    end
  end
end
