class CreateMembershipTimeSharings < ActiveRecord::Migration[8.1]
  def change
    # A person's own times shown on that household's calendar, as a record: it exists while they share
    # (docs/design/calendar.md, Membership::TimeSharing). The unique index is what create_or_find_by! relies on, so a
    # double save makes one row; deleting the seat takes it with it.
    create_table :membership_time_sharings, id: :uuid do |t|
      t.references :membership, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.timestamps
    end
  end
end
