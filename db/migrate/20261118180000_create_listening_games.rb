class CreateListeningGames < ActiveRecord::Migration[8.1]
  # A household's listening game for one week, its rounds of four cards and the pages the AI used
  # (docs/design/listening-game.md, Models), asked for under the listening_game purpose.
  def up
    remove_check_constraint :chats, name: "chats_purpose_check"
    add_check_constraint :chats, "purpose IN ('family_study_draft', 'personal_study', 'meeting_part', 'daily_brief', 'listening_game')", name: "chats_purpose_check"
    remove_check_constraint :ai_uses, name: "ai_uses_purpose_check"
    add_check_constraint :ai_uses, "purpose IN ('family_study_draft', 'personal_study', 'meeting_part', 'daily_brief', 'listening_game')", name: "ai_uses_purpose_check"

    create_table :listening_games, id: :uuid do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.date :week_of, null: false
      # The purge deletes the chat after 7 days; the game stays.
      t.references :chat, foreign_key: { on_delete: :nullify }, type: :uuid
      t.timestamps

      t.index %i[ household_id week_of ], unique: true
    end

    create_table :listening_game_sources, id: :uuid do |t|
      t.references :listening_game, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.integer :position, limit: 2, null: false
      t.string :title, null: false
      t.string :url, null: false
      t.timestamps

      t.index %i[ listening_game_id position ], unique: true
      t.check_constraint "url LIKE 'https://%'", name: "listening_game_sources_url_check"
    end

    create_table :listening_game_rounds, id: :uuid do |t|
      t.references :listening_game, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.string :step, null: false
      t.integer :position, limit: 2, null: false
      # Set when a head or adult changes the round. A later story.
      t.references :changed_by, foreign_key: { to_table: :users, on_delete: :nullify }, type: :uuid
      t.timestamps

      t.index %i[ listening_game_id step position ], unique: true, name: "index_listening_game_rounds_on_game_step_position"
      t.check_constraint "step IN ('talk', 'spiritual_gems', 'bible_reading', 'congregation_bible_study')", name: "listening_game_rounds_step_check"
    end

    create_table :listening_game_cards, id: :uuid do |t|
      t.references :round, null: false, foreign_key: { to_table: :listening_game_rounds, on_delete: :cascade }, type: :uuid, index: false
      t.integer :position, limit: 2, null: false
      t.string :label, null: false
      t.string :kind, null: false
      t.boolean :answer, null: false, default: false
      t.timestamps

      t.index %i[ round_id position ], unique: true
      # One answer per round, whatever the AI returns (Trap 3).
      t.index :round_id, unique: true, where: "answer", name: "index_listening_game_cards_on_round_id_answer"
      t.check_constraint "position BETWEEN 1 AND 4", name: "listening_game_cards_position_check"
      t.check_constraint "char_length(label) <= 40", name: "listening_game_cards_label_check"
      t.check_constraint "kind IN ('person', 'place', 'book', 'thing', 'feeling', 'action')", name: "listening_game_cards_kind_check"
    end
  end

  def down
    drop_table :listening_game_cards
    drop_table :listening_game_rounds
    drop_table :listening_game_sources
    drop_table :listening_games
    execute "DELETE FROM ai_uses WHERE purpose = 'listening_game'"
    execute "DELETE FROM messages WHERE chat_id IN (SELECT id FROM chats WHERE purpose = 'listening_game')"
    execute "DELETE FROM ruby_llm_usages WHERE chat_type = 'Chat' AND chat_id IN (SELECT id FROM chats WHERE purpose = 'listening_game')"
    execute "DELETE FROM chats WHERE purpose = 'listening_game'"
    remove_check_constraint :ai_uses, name: "ai_uses_purpose_check"
    add_check_constraint :ai_uses, "purpose IN ('family_study_draft', 'personal_study', 'meeting_part', 'daily_brief')", name: "ai_uses_purpose_check"
    remove_check_constraint :chats, name: "chats_purpose_check"
    add_check_constraint :chats, "purpose IN ('family_study_draft', 'personal_study', 'meeting_part', 'daily_brief')", name: "chats_purpose_check"
  end
end
