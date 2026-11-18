class CreateDailyBriefPauses < ActiveRecord::Migration[8.1]
  # A paused daily brief is a record, not a flag: starting it again deletes it (docs/design/daily-brief.md,
  # DailyBrief::Pause). The reason is the person's choice, or seven briefs in a row they never saw.
  def change
    create_table :daily_brief_pauses, id: :uuid do |t|
      t.references :plan, null: false, foreign_key: { to_table: :daily_brief_plans, on_delete: :cascade }, type: :uuid, index: { unique: true }
      t.string :reason, null: false
      t.datetime :created_at, null: false

      t.check_constraint "reason IN ('chosen', 'unseen')", name: "daily_brief_pauses_reason_check"
    end
  end
end
