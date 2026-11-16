class AddPersonalStudyToChats < ActiveRecord::Migration[8.1]
  # A personal study's conversation is a chat under the personal_study purpose, one per study
  # (docs/design/personal-study.md, PersonalStudy).
  def up
    remove_check_constraint :chats, name: "chats_purpose_check"
    add_check_constraint :chats, "purpose IN ('family_study_draft', 'personal_study')", name: "chats_purpose_check"

    add_reference :personal_studies, :chat, foreign_key: true, type: :uuid, index: { unique: true }
    # Studies made before this story get their chat now, so the column can be required.
    select_rows("SELECT id, user_id FROM personal_studies").each do |study_id, user_id|
      chat = Chat.create!(user_id: user_id, purpose: "personal_study")
      execute "UPDATE personal_studies SET chat_id = #{quote(chat.id)} WHERE id = #{quote(study_id)}"
    end
    change_column_null :personal_studies, :chat_id, false
  end

  def down
    remove_reference :personal_studies, :chat
    execute "DELETE FROM messages WHERE chat_id IN (SELECT id FROM chats WHERE purpose = 'personal_study')"
    execute "DELETE FROM ruby_llm_usages WHERE chat_type = 'Chat' AND chat_id IN (SELECT id FROM chats WHERE purpose = 'personal_study')"
    execute "DELETE FROM chats WHERE purpose = 'personal_study'"
    remove_check_constraint :chats, name: "chats_purpose_check"
    add_check_constraint :chats, "purpose IN ('family_study_draft')", name: "chats_purpose_check"
  end
end
