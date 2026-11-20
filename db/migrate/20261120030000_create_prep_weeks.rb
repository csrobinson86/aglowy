class CreatePrepWeeks < ActiveRecord::Migration[8.1]
  PURPOSES = %w[ family_study_draft personal_study meeting_part daily_brief listening_game ].freeze

  # A household's Get ready cards for one week, the pages the AI used, and the claim a run holds while it asks
  # (docs/design/meeting-prep.md, Models), asked for under the meeting_prep purpose.
  def up
    purposes_check [ *PURPOSES, "meeting_prep" ]

    create_table :prep_weeks, id: :uuid do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.date :week_of, null: false
      # The purge deletes the chat after 7 days; the week stays.
      t.references :chat, foreign_key: { on_delete: :nullify }, type: :uuid
      t.timestamps

      t.index %i[ household_id week_of ], unique: true
    end

    create_table :prep_week_cards, id: :uuid do |t|
      t.references :prep_week, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.string :meeting, null: false
      t.string :step, null: false
      # The text is encrypted, so its lengths are checked in the model (PrepWeek::Card).
      t.text :about, null: false
      t.string :quality, null: false
      t.text :quality_line, null: false
      t.text :i_can, null: false
      t.text :reading
      t.text :story
      # Set when a head or adult changes the card. A later story.
      t.references :changed_by, foreign_key: { to_table: :users, on_delete: :nullify }, type: :uuid
      t.timestamps

      t.index %i[ prep_week_id step ], unique: true
      t.check_constraint "meeting IN ('midweek', 'weekend')", name: "prep_week_cards_meeting_check"
      t.check_constraint "step IN ('talk', 'bible_reading', 'living', 'congregation_bible_study', 'watchtower_study')", name: "prep_week_cards_step_check"
      t.check_constraint "(step = 'watchtower_study') = (meeting = 'weekend')", name: "prep_week_cards_step_meeting_check"
      t.check_constraint "quality IN ('loving', 'caring', 'kind', 'wise', 'fair', 'strong', 'patient', 'generous', 'forgiving', 'faithful')",
                         name: "prep_week_cards_quality_check"
      t.check_constraint "step = 'bible_reading' OR (reading IS NULL AND story IS NULL)", name: "prep_week_cards_reading_check"
    end

    create_table :prep_week_sources, id: :uuid do |t|
      t.references :prep_week, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.integer :position, limit: 2, null: false
      t.string :title, null: false
      t.string :url, null: false
      t.timestamps

      t.index %i[ prep_week_id position ], unique: true
      t.check_constraint "url LIKE 'https://%'", name: "prep_week_sources_url_check"
    end

    # No updated_at: taking a claim over moves its created_at.
    create_table :prep_week_preparations, id: :uuid do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.date :week_of, null: false
      t.uuid :token, null: false
      t.datetime :created_at, null: false

      t.index %i[ household_id week_of ], unique: true
    end
  end

  def down
    drop_table :prep_week_preparations
    drop_table :prep_week_sources
    drop_table :prep_week_cards
    drop_table :prep_weeks
    execute "DELETE FROM ai_uses WHERE purpose = 'meeting_prep'"
    execute "DELETE FROM messages WHERE chat_id IN (SELECT id FROM chats WHERE purpose = 'meeting_prep')"
    execute "DELETE FROM ruby_llm_usages WHERE chat_type = 'Chat' AND chat_id IN (SELECT id FROM chats WHERE purpose = 'meeting_prep')"
    execute "DELETE FROM chats WHERE purpose = 'meeting_prep'"
    purposes_check PURPOSES
  end

  private
    # Chats and uses take the same purposes (Ai::Purpose::CLASSES).
    def purposes_check(purposes)
      { chats: "chats_purpose_check", ai_uses: "ai_uses_purpose_check" }.each do |table, name|
        remove_check_constraint table, name: name
        add_check_constraint table, "purpose IN (#{purposes.map { "'#{it}'" }.join(", ")})", name: name
      end
    end
end
