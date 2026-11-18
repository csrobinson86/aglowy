class CreateDailyBriefWritings < ActiveRecord::Migration[8.1]
  # The AI part of a daily brief (docs/design/daily-brief.md, DailyBrief::Writing): one request and its checked reply,
  # each in its own chat under the daily_brief purpose, with its Ai::Use for the person's 3 a day.
  def up
    remove_check_constraint :chats, name: "chats_purpose_check"
    add_check_constraint :chats, "purpose IN ('family_study_draft', 'personal_study', 'meeting_part', 'daily_brief')", name: "chats_purpose_check"
    remove_check_constraint :ai_uses, name: "ai_uses_purpose_check"
    add_check_constraint :ai_uses, "purpose IN ('family_study_draft', 'personal_study', 'meeting_part', 'daily_brief')", name: "ai_uses_purpose_check"

    create_table :daily_brief_writings, id: :uuid do |t|
      t.references :daily_brief, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      # The purge deletes the chat, and the writing goes with it.
      t.references :chat, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: { unique: true }
      t.string :status, null: false, default: "writing"
      t.jsonb :result
      t.jsonb :sources, null: false, default: []
      t.timestamps

      t.check_constraint "status IN ('writing', 'written', 'off_topic', 'flagged', 'failed', 'stopped')", name: "daily_brief_writings_status_check"
    end

    # Kept when the writing goes, so deleting a brief can't give a request back.
    add_reference :ai_uses, :daily_brief_writing, foreign_key: { on_delete: :nullify }, type: :uuid, index: { unique: true }
  end

  def down
    remove_reference :ai_uses, :daily_brief_writing
    drop_table :daily_brief_writings
    execute "DELETE FROM ai_uses WHERE purpose = 'daily_brief'"
    execute "DELETE FROM messages WHERE chat_id IN (SELECT id FROM chats WHERE purpose = 'daily_brief')"
    execute "DELETE FROM ruby_llm_usages WHERE chat_type = 'Chat' AND chat_id IN (SELECT id FROM chats WHERE purpose = 'daily_brief')"
    execute "DELETE FROM chats WHERE purpose = 'daily_brief'"
    remove_check_constraint :ai_uses, name: "ai_uses_purpose_check"
    add_check_constraint :ai_uses, "purpose IN ('family_study_draft', 'personal_study', 'meeting_part')", name: "ai_uses_purpose_check"
    remove_check_constraint :chats, name: "chats_purpose_check"
    add_check_constraint :chats, "purpose IN ('family_study_draft', 'personal_study', 'meeting_part')", name: "chats_purpose_check"
  end
end
