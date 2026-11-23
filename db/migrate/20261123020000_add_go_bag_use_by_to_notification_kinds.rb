class AddGoBagUseByToNotificationKinds < ActiveRecord::Migration[8.1]
  KINDS = %w[ weekly_preview study_topic_needed shared_with_you invitation_unaccepted ].freeze

  # The go-bag use-by reminder (docs/design/go-bags.md, The use-by reminder). Notifications and settings take the same
  # kinds (Notification::Kind.kinds).
  def up
    kinds_check [ *KINDS, "go_bag_use_by" ]
  end

  def down
    execute "DELETE FROM notifications WHERE kind = 'go_bag_use_by'"
    execute "DELETE FROM notification_settings WHERE kind = 'go_bag_use_by'"
    kinds_check KINDS
  end

  private
    def kinds_check(kinds)
      { notifications: "notifications_kind_check", notification_settings: "notification_settings_kind_check" }.each do |table, name|
        remove_check_constraint table, name: name
        add_check_constraint table, "kind IN (#{kinds.map { "'#{it}'" }.join(", ")})", name: name
      end
    end
end
