# The inbox's groups and times, in the person's own zone (docs/design/notifications.md, The inbox).
module NotificationsHelper
  # "Today" and "Earlier", each keeping the newest-first order, leaving out a group with none.
  def notifications_by_day(notifications, zone)
    today = Time.current.in_time_zone(zone).to_date
    notifications.group_by { it.created_at.in_time_zone(zone).to_date == today ? "Today" : "Earlier" }
  end

  # "8:00 AM" today, "Friday" in the week before, "November 3" before that.
  def notification_time(notification, zone)
    time, today = notification.created_at.in_time_zone(zone), Time.current.in_time_zone(zone).to_date

    if time.to_date == today
      time.strftime("%-l:%M %p")
    elsif time.to_date > today - 7
      time.strftime("%A")
    else
      time.strftime("%B %-d")
    end
  end

  # Under a device in Phones and browsers: "Added November 12 · last used today", in the person's zone.
  def push_subscription_dates(subscription, zone)
    today = Time.current.in_time_zone(zone).to_date
    day = ->(time) { time.in_time_zone(zone).to_date.then { { today => "today", today - 1 => "yesterday" }.fetch(it) { it.strftime("%B %-d") } } }

    [ "Added #{subscription.created_at.in_time_zone(zone).strftime("%B %-d")}", ("last used #{day.(subscription.last_used_at)}" if subscription.last_used_at) ].compact.join(" · ")
  end
end
