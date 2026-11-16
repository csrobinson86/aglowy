class CreateChats < ActiveRecord::Migration[8.1]
  def change
    # RubyLLM's chats, plus whose request it was, the household it ran in and its Ai::Purpose
    # (docs/design/ai.md, Conversations).
    create_table :chats, id: :uuid do |t|
      t.references :ruby_llm_model, null: false, foreign_key: { to_table: :ruby_llm_models }, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :household, foreign_key: true, type: :uuid
      t.string :purpose, null: false
      t.boolean :cancelled, null: false, default: false
      t.string :claim_token
      t.datetime :claimed_until
      t.timestamps

      t.index :claimed_until, where: "claim_token IS NOT NULL"
      t.index :created_at
      t.check_constraint "purpose IN ('family_study_draft')", name: "chats_purpose_check"
    end
  end
end
