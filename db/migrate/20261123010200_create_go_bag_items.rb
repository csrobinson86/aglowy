class CreateGoBagItems < ActiveRecord::Migration[8.1]
  # What's in a bag (docs/design/go-bags.md, GoBag::Item). Deleting a category keeps its items, under No category.
  def change
    create_table :go_bag_items, id: :uuid do |t|
      t.references :go_bag, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :category, foreign_key: { to_table: :go_bag_categories, on_delete: :nullify }, type: :uuid
      t.string :name, null: false
      t.string :quantity
      t.string :stored_at
      t.date :use_by
      t.timestamps
    end
  end
end
