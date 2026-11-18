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

  test "a draft goes when its chat is purged" do
    draft = travel_to(8.days.ago) { family_study_draft(status: "drafted") }

    Ai::PurgeExpiredChatsJob.perform_now

    assert_not FamilyStudy::Draft.exists?(draft.id)
  end

  private
    def chat_created(at)
      travel_to(at) do
        Chat.create!(user: users(:head), household: households(:home), purpose: "family_study_draft").tap do
          it.messages.create!(role: "user", content: "Prayer")
        end
      end
    end

  test "a 61-day-old meeting part draft goes with its chat and messages; a 59-day-old draft of the same part stays, and so do the part and its preparation" do
    part = meeting_parts(:head_conversation)
    part.update!(preparation: "<p>My own words.</p>")
    old = travel_to(61.days.ago) { meeting_part_draft(part, status: "drafted").tap { it.chat.messages.create!(role: "user", content: "Starting a Conversation") } }
    recent = travel_to(59.days.ago) { meeting_part_draft(part, status: "drafted") }

    Ai::PurgeExpiredChatsJob.perform_now

    assert_not MeetingPart::Draft.exists?(old.id)
    assert_not Chat.exists?(old.chat_id)
    assert_empty Message.where(chat_id: old.chat_id)
    assert MeetingPart::Draft.exists?(recent.id)
    assert Chat.exists?(recent.chat_id)
    assert_equal "My own words.", part.reload.preparation.to_plain_text
  end
end
