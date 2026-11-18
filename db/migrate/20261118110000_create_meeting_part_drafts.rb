class CreateMeetingPartDrafts < ActiveRecord::Migration[8.1]
  # AI drafts for a meeting part (docs/design/meeting-parts.md, MeetingPart::Draft): one request and its checked reply,
  # each in its own chat under the meeting_part purpose, with its Ai::Use for the person's 15 a day.
  def up
    remove_check_constraint :chats, name: "chats_purpose_check"
    add_check_constraint :chats, "purpose IN ('family_study_draft', 'personal_study', 'meeting_part')", name: "chats_purpose_check"
    remove_check_constraint :ai_uses, name: "ai_uses_purpose_check"
    add_check_constraint :ai_uses, "purpose IN ('family_study_draft', 'personal_study', 'meeting_part')", name: "ai_uses_purpose_check"

    create_table :meeting_part_drafts, id: :uuid do |t|
      t.references :meeting_part, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      # The purge deletes the chat, and the draft goes with it.
      t.references :chat, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: { unique: true }
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :kind, null: false
      t.text :request
      # The draft a change, or sample wording, was built on, and the copy of its result that's sent. Later stories.
      t.references :revises, foreign_key: { to_table: :meeting_part_drafts, on_delete: :nullify }, type: :uuid
      t.jsonb :revised_result
      t.string :status, null: false, default: "drafting"
      t.jsonb :result
      t.jsonb :sources, null: false, default: []
      t.timestamps

      t.check_constraint "kind IN ('outline', 'wording')", name: "meeting_part_drafts_kind_check"
      t.check_constraint "status IN ('drafting', 'drafted', 'off_topic', 'flagged', 'failed', 'stopped', 'discarded')", name: "meeting_part_drafts_status_check"
    end

    # Kept when the draft goes, so deleting a draft or its part can't give a request back.
    add_reference :ai_uses, :meeting_part_draft, foreign_key: { on_delete: :nullify }, type: :uuid, index: { unique: true }
  end

  def down
    remove_reference :ai_uses, :meeting_part_draft
    drop_table :meeting_part_drafts
    execute "DELETE FROM ai_uses WHERE purpose = 'meeting_part'"
    execute "DELETE FROM messages WHERE chat_id IN (SELECT id FROM chats WHERE purpose = 'meeting_part')"
    execute "DELETE FROM ruby_llm_usages WHERE chat_type = 'Chat' AND chat_id IN (SELECT id FROM chats WHERE purpose = 'meeting_part')"
    execute "DELETE FROM chats WHERE purpose = 'meeting_part'"
    remove_check_constraint :ai_uses, name: "ai_uses_purpose_check"
    add_check_constraint :ai_uses, "purpose IN ('family_study_draft', 'personal_study')", name: "ai_uses_purpose_check"
    remove_check_constraint :chats, name: "chats_purpose_check"
    add_check_constraint :chats, "purpose IN ('family_study_draft', 'personal_study')", name: "chats_purpose_check"
  end
end
