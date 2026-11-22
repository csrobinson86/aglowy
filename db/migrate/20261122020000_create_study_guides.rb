class CreateStudyGuides < ActiveRecord::Migration[8.1]
  PURPOSES = %w[ family_study_draft personal_study meeting_part daily_brief listening_game meeting_prep ].freeze

  # A person's study guide for one week, its parts, the pages the AI used, and the claim a run holds while it asks
  # (docs/design/study-guide.md, Models), asked for under the study_guide purpose.
  def up
    purposes_check [ *PURPOSES, "study_guide" ]

    create_table :study_guides, id: :uuid do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.date :week_of, null: false
      # The purge deletes the chat after 7 days; the guide stays.
      t.references :chat, foreign_key: { on_delete: :nullify }, type: :uuid
      t.timestamps

      t.index %i[ user_id week_of ], unique: true
    end

    # No updated_at: a saved part is never changed.
    create_table :study_guide_parts, id: :uuid do |t|
      t.references :study_guide, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.string :step, null: false
      # The step's fields as encrypted JSON, so the model checks them against the step's shape (StudyGuide::Part).
      t.text :content, null: false
      t.datetime :created_at, null: false

      t.index %i[ study_guide_id step ], unique: true
      t.check_constraint "step IN ('midweek_overview', 'talk', 'spiritual_gems', 'bible_reading', 'field_ministry', 'living', " \
                         "'congregation_bible_study', 'weekend_overview', 'watchtower_study')", name: "study_guide_parts_step_check"
    end

    create_table :study_guide_sources, id: :uuid do |t|
      t.references :study_guide, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.integer :position, limit: 2, null: false
      t.string :title, null: false
      t.string :url, null: false
      t.timestamps

      t.index %i[ study_guide_id position ], unique: true
      t.check_constraint "url LIKE 'https://%'", name: "study_guide_sources_url_check"
    end

    # No updated_at: taking a claim over moves its created_at.
    create_table :study_guide_preparations, id: :uuid do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.date :week_of, null: false
      t.uuid :token, null: false
      t.datetime :created_at, null: false

      t.index %i[ user_id week_of ], unique: true
    end
  end

  def down
    drop_table :study_guide_preparations
    drop_table :study_guide_sources
    drop_table :study_guide_parts
    drop_table :study_guides
    execute "DELETE FROM ai_uses WHERE purpose = 'study_guide'"
    execute "DELETE FROM messages WHERE chat_id IN (SELECT id FROM chats WHERE purpose = 'study_guide')"
    execute "DELETE FROM ruby_llm_usages WHERE chat_type = 'Chat' AND chat_id IN (SELECT id FROM chats WHERE purpose = 'study_guide')"
    execute "DELETE FROM chats WHERE purpose = 'study_guide'"
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
