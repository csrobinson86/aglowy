require "test_helper"

class Ai::PurgeExpiredChatsJobTest < ActiveJob::TestCase
  test "an 8-day-old chat and its messages are gone; a 6-day-old one stays" do
    old = chat_created(8.days.ago)
    recent = chat_created(6.days.ago)

    Ai::PurgeExpiredChatsJob.perform_now

    assert_not Chat.exists?(old.id)
    assert_empty Message.where(chat_id: old.id)
    assert Chat.exists?(recent.id)
    assert_equal 1, recent.messages.count
  end

  private
    def chat_created(at)
      travel_to(at) do
        Chat.create!(user: users(:head), household: households(:home), purpose: "family_study_draft").tap do
          it.messages.create!(role: "user", content: "Prayer")
        end
      end
    end
end
