# Deletes Ai::Use rows after 2 days, daily from config/recurring.yml: by then no daily limit counts them.
class Ai::PurgeExpiredUsesJob < ApplicationJob
  def perform
    Ai::Use.expired.delete_all
  end
end
