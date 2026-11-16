class CreateCollections < ActiveRecord::Migration[8.1]
  def change
    # Each person's folders, shared between Personal study and Notes or used in one (docs/design/personal-study.md, Collection).
    create_table :collections, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false
      t.string :name, null: false
      t.string :used_in, null: false, default: "both"
      t.integer :position, null: false
      t.timestamps

      t.index %i[ user_id name ], unique: true
      t.check_constraint "char_length(name) BETWEEN 1 AND 40", name: "collections_name_length_check"
      t.check_constraint "used_in IN ('both', 'studies', 'notes')", name: "collections_used_in_check"
    end
  end
end
