class CreateGoBagItemAcquisitions < ActiveRecord::Migration[8.1]
  # "We have it", one per item (docs/design/go-bags.md, GoBag::Item::Acquisition).
  def change
    create_table :go_bag_item_acquisitions, id: :uuid do |t|
      t.references :item, null: false, foreign_key: { to_table: :go_bag_items, on_delete: :cascade }, type: :uuid, index: { unique: true }
      t.references :acquired_by, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.datetime :created_at, null: false
    end
  end
end
