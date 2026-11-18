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

  test "a change made 10 days ago revises a 61-day-old draft, and sample wording made 10 days ago revises a 61-day-old outline: the purge deletes each older draft and its chat; each newer draft keeps its revised_result, its chat and its messages, with revises nil. 61 days after the newer drafts were made, they, their copies and their chats go" do
    part = meeting_parts(:head_conversation)
    outline = { "aim" => "Leave the person curious.", "points" => [ { "heading" => "A promise worth hearing" } ] }
    older = travel_to(61.days.ago) { Array.new(2) { meeting_part_draft(part, status: "drafted", result: outline) } }
    newer = travel_to(10.days.ago) do
      [ meeting_part_draft(part, status: "drafted", revises: older.first, revised_result: outline, request: "Shorter opening"),
        meeting_part_draft(part, kind: "wording", status: "drafted", revises: older.last, revised_result: outline) ].each do
        it.chat.messages.create!(role: "user", content: "Starting a Conversation")
      end
    end

    Ai::PurgeExpiredChatsJob.perform_now

    older.each do
      assert_not MeetingPart::Draft.exists?(it.id)
      assert_not Chat.exists?(it.chat_id)
    end
    newer.each do
      it.reload
      assert_nil it.revises_id
      assert_equal outline, it.revised_result
      assert Chat.exists?(it.chat_id)
      assert_equal 1, it.chat.messages.count
    end

    travel_to(newer.first.created_at + 61.days) { Ai::PurgeExpiredChatsJob.perform_now }

    newer.each do
      assert_not MeetingPart::Draft.exists?(it.id)
      assert_not Chat.exists?(it.chat_id)
      assert_empty Message.where(chat_id: it.chat_id)
    end
  end
end
