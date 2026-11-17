class CreateCalendarFeeds < ActiveRecord::Migration[8.1]
  def change
    # A person's private subscribe link for their phone's calendar (docs/design/calendar.md, CalendarFeed). One per
    # person; the token is encrypted deterministically, so it can still be found by, and stays unique.
    create_table :calendar_feeds, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.string :token, null: false, index: { unique: true }
      t.timestamps
    end
  end
end
