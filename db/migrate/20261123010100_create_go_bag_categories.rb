class CreateGoBagCategories < ActiveRecord::Migration[8.1]
  # The household's categories, shared by its bags (docs/design/go-bags.md, GoBag::Category). suggestion_key marks one
  # made from the suggestions, once per household; categories people add have none, and Postgres lets nulls repeat.
  def change
    create_table :go_bag_categories, id: :uuid do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: false
      t.string :name, null: false
      t.integer :position, null: false
      t.string :suggestion_key
      t.timestamps

      t.index %i[ household_id suggestion_key ], unique: true
    end
  end
end
