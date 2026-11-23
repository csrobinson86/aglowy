# The use-by reminder for an item just saved or ticked with a date already close (GoBag::Item#remind_about_use_by_later).
# An item removed in the meantime has nothing to replace.
class GoBag::Item::UseByReminderJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(item)
    item.remind_about_use_by_now
  end
end
