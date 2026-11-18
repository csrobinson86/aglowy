class CreateDailyBriefPlans < ActiveRecord::Migration[8.1]
  # A person's daily brief plan: its focus areas and a week of rows (docs/design/daily-brief.md, Data model). What the
  # person types is encrypted, so those lengths are checked by validations only.
  def change
    create_table :daily_brief_plans, id: :uuid do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: { unique: true }
      t.integer :ready_at_minutes, null: false, default: 300
      t.string :sections, array: true, null: false, default: %w[ daily_text reading faith_example children evening ]
      t.datetime :started_at, null: false
      t.timestamps

      t.check_constraint "ready_at_minutes BETWEEN 240 AND 480 AND ready_at_minutes % 30 = 0", name: "daily_brief_plans_ready_at_minutes_check"
      t.check_constraint "sections <@ ARRAY['daily_text', 'reading', 'faith_example', 'children', 'evening']::varchar[]",
                         name: "daily_brief_plans_sections_check"
    end

    create_table :daily_brief_focus_areas, id: :uuid do |t|
      t.references :plan, null: false, foreign_key: { to_table: :daily_brief_plans, on_delete: :cascade }, type: :uuid
      t.integer :position, null: false
      t.string :kind, null: false
      t.string :name, null: false
      t.text :gives, null: false
      t.string :scriptures
      t.references :goal, foreign_key: { on_delete: :nullify }, type: :uuid
      t.timestamps

      t.index :plan_id, unique: true, where: "kind = 'quality'", name: "index_daily_brief_focus_areas_one_quality"
      t.index :plan_id, unique: true, where: "kind = 'appreciation'", name: "index_daily_brief_focus_areas_one_appreciation"
      t.check_constraint "kind IN ('role', 'quality', 'appreciation')", name: "daily_brief_focus_areas_kind_check"
      t.check_constraint "char_length(scriptures) <= 120", name: "daily_brief_focus_areas_scriptures_check"
    end

    create_table :daily_brief_days, id: :uuid do |t|
      t.references :plan, null: false, foreign_key: { to_table: :daily_brief_plans, on_delete: :cascade }, type: :uuid, index: false
      t.integer :wday, null: false
      t.string :reading
      t.string :examples
      t.jsonb :topics, null: false, default: {}
      t.timestamps

      t.index %i[ plan_id wday ], unique: true
      t.check_constraint "wday BETWEEN 0 AND 6", name: "daily_brief_days_wday_check"
    end
  end
end
