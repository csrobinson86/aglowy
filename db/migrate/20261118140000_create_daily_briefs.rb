class CreateDailyBriefs < ActiveRecord::Migration[8.1]
  # One day's brief: a copy of the plan it was built from, and when the person first saw it (docs/design/daily-brief.md,
  # DailyBrief). One a day per person, by the unique index. The copy is encrypted, so it's a JSON string in jsonb.
  def change
    create_table :daily_briefs, id: :uuid do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.date :on, null: false
      t.jsonb :plan, null: false
      t.datetime :seen_at
      t.timestamps

      t.index %i[ user_id on ], unique: true
    end
  end
end
