class CreateUserWeeklyStudyGuides < ActiveRecord::Migration[8.1]
  def change
    # The study guide setting is a record: it exists while the person's study guide is on (docs/design/study-guide.md,
    # Models). The unique index is what create_or_find_by! relies on, so turning it on twice at once makes one row.
    create_table :user_weekly_study_guides, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.timestamps
    end
  end
end
